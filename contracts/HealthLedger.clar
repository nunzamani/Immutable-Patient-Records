(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PATIENT (err u101))
(define-constant ERR_RECORD_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_PERMISSION (err u104))
(define-constant ERR_ACCESS_DENIED (err u105))
(define-constant ERR_INVALID_DATA (err u106))
(define-constant ERR_PRESCRIPTION_NOT_FOUND (err u107))
(define-constant ERR_PRESCRIPTION_EXPIRED (err u108))
(define-constant ERR_ALREADY_FILLED (err u109))
(define-constant ERR_INVALID_PHARMACY (err u110))
(define-constant ERR_INSUFFICIENT_REFILLS (err u111))
(define-constant ERR_INVALID_CATEGORY (err u112))
(define-constant ERR_INVALID_PRIORITY (err u113))
(define-constant ERR_NOT_CLASSIFIED (err u114))
(define-constant ERR_INVALID_ALERT_TYPE (err u115))
(define-constant ERR_INVALID_SEVERITY (err u116))
(define-constant ERR_ALERT_NOT_FOUND (err u117))
(define-constant ERR_DUPLICATE_ALERT (err u118))
(define-constant ERR_INVALID_ALERT_STATUS (err u119))

(define-constant SEVERITY_CRITICAL u4)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_LOW u1)

(define-constant ALERT_TYPE_ALLERGY u1)
(define-constant ALERT_TYPE_DRUG_INTERACTION u2)
(define-constant ALERT_TYPE_CONTRAINDICATION u3)
(define-constant ALERT_TYPE_WARNING u4)

(define-data-var next-record-id uint u1)
(define-data-var total-records uint u0)
(define-data-var total-patients uint u0)

(define-map patients principal {
    patient-id: uint,
    created-at: uint,
    active: bool,
    emergency-contact: (optional principal)
})

(define-map patient-records uint {
    patient: principal,
    record-hash: (string-ascii 64),
    record-type: (string-ascii 32),
    created-by: principal,
    created-at: uint,
    encrypted: bool,
    metadata: (string-ascii 256)
})

(define-map access-permissions { patient: principal, accessor: principal } {
    granted-by: principal,
    permission-level: (string-ascii 16),
    granted-at: uint,
    expires-at: (optional uint),
    active: bool
})

(define-map healthcare-providers principal {
    provider-id: uint,
    verified: bool,
    specialty: (string-ascii 64),
    verified-by: principal,
    verified-at: uint
})

(define-map access-logs uint {
    record-id: uint,
    accessor: principal,
    access-type: (string-ascii 16),
    accessed-at: uint,
    ip-hash: (optional (string-ascii 64))
})

(define-map prescriptions uint {
    patient: principal,
    prescriber: principal,
    medication: (string-ascii 64),
    dosage: (string-ascii 32),
    quantity: uint,
    refills-remaining: uint,
    max-refills: uint,
    issued-at: uint,
    expires-at: uint,
    active: bool,
    instructions: (string-ascii 256)
})

(define-map pharmacies principal {
    pharmacy-id: uint,
    name: (string-ascii 64),
    license-number: (string-ascii 32),
    verified: bool,
    registered-at: uint
})

(define-map prescription-fills uint {
    prescription-id: uint,
    pharmacy: principal,
    filled-at: uint,
    quantity-dispensed: uint,
    pharmacist: principal,
    fill-number: uint
})

(define-data-var next-log-id uint u1)
(define-data-var next-prescription-id uint u1)
(define-data-var total-prescriptions uint u0)

(define-map record-classifications { record-id: uint, patient: principal } {
    category: (string-ascii 20),
    priority: uint
})

(define-map medical-alerts { patient: principal, alert-id: uint } {
    alert-type: uint,
    severity: uint,
    substance: (string-ascii 100),
    description: (string-ascii 500),
    created-by: principal,
    created-at: uint,
    updated-at: uint,
    is-active: bool
})

(define-map patient-alert-count principal uint)
(define-map alert-type-index { patient: principal, alert-type: uint, index: uint } { alert-id: uint })
(define-map alert-type-count { patient: principal, alert-type: uint } uint)

(define-data-var next-global-alert-id uint u0)

(define-public (register-patient (emergency-contact (optional principal)))
    (let ((patient-id (var-get total-patients)))
        (asserts! (is-none (map-get? patients tx-sender)) ERR_ALREADY_EXISTS)
        (map-set patients tx-sender {
            patient-id: patient-id,
            created-at: stacks-block-height,
            active: true,
            emergency-contact: emergency-contact
        })
        (var-set total-patients (+ patient-id u1))
        (ok patient-id)))

(define-public (register-provider (specialty (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set healthcare-providers tx-sender {
            provider-id: (var-get total-patients),
            verified: true,
            specialty: specialty,
            verified-by: CONTRACT_OWNER,
            verified-at: stacks-block-height
        })
        (ok true)))

(define-public (create-record 
    (patient principal)
    (record-hash (string-ascii 64))
    (record-type (string-ascii 32))
    (encrypted bool)
    (metadata (string-ascii 256)))
    (let ((record-id (var-get next-record-id)))
        (asserts! (is-some (map-get? patients patient)) ERR_INVALID_PATIENT)
        (asserts! (or (is-eq tx-sender patient) 
                      (has-permission patient tx-sender "write")) ERR_NOT_AUTHORIZED)
        (asserts! (> (len record-hash) u0) ERR_INVALID_DATA)
        
        (map-set patient-records record-id {
            patient: patient,
            record-hash: record-hash,
            record-type: record-type,
            created-by: tx-sender,
            created-at: stacks-block-height,
            encrypted: encrypted,
            metadata: metadata
        })
        
        (var-set next-record-id (+ record-id u1))
        (var-set total-records (+ (var-get total-records) u1))
        (log-access record-id tx-sender "create" none)
        (ok record-id)))

(define-public (grant-access 
    (accessor principal)
    (permission-level (string-ascii 16))
    (expires-at (optional uint)))
    (begin
        (asserts! (is-some (map-get? patients tx-sender)) ERR_INVALID_PATIENT)
        (asserts! (or (is-eq permission-level "read") 
                      (is-eq permission-level "write") 
                      (is-eq permission-level "full")) ERR_INVALID_PERMISSION)
        
        (map-set access-permissions { patient: tx-sender, accessor: accessor } {
            granted-by: tx-sender,
            permission-level: permission-level,
            granted-at: stacks-block-height,
            expires-at: expires-at,
            active: true
        })
        (ok true)))

(define-public (revoke-access (accessor principal))
    (begin
        (asserts! (is-some (map-get? patients tx-sender)) ERR_INVALID_PATIENT)
        (asserts! (is-some (map-get? access-permissions { patient: tx-sender, accessor: accessor }))
                  ERR_INVALID_PERMISSION)
        
        (map-delete access-permissions { patient: tx-sender, accessor: accessor })
        (ok true)))

(define-public (emergency-access (patient principal))
    (let ((patient-info (unwrap! (map-get? patients patient) ERR_INVALID_PATIENT)))
        (asserts! (is-eq tx-sender (unwrap! (get emergency-contact patient-info) ERR_NOT_AUTHORIZED))
                  ERR_NOT_AUTHORIZED)
        
        (map-set access-permissions { patient: patient, accessor: tx-sender } {
            granted-by: patient,
            permission-level: "read",
            granted-at: stacks-block-height,
            expires-at: (some (+ stacks-block-height u144)), ;; 24 hours emergency access
            active: true
        })
        (ok true)))

(define-read-only (get-patient-info (patient principal))
    (map-get? patients patient))

(define-public (get-record (record-id uint))
    (let ((record (unwrap! (map-get? patient-records record-id) ERR_RECORD_NOT_FOUND)))
        (if (can-access-record (get patient record) tx-sender)
            (begin
                (log-access record-id tx-sender "read" none)
                (ok record))
            ERR_ACCESS_DENIED)))

(define-read-only (get-patient-records (patient principal))
    (if (can-access-record patient tx-sender)
        (ok (filter-records patient))
        ERR_ACCESS_DENIED))

(define-read-only (has-permission (patient principal) (accessor principal) (level (string-ascii 16)))
    (match (map-get? access-permissions { patient: patient, accessor: accessor })
        permission (and (get active permission)
                       (or (is-none (get expires-at permission))
                           (< stacks-block-height (unwrap-panic (get expires-at permission))))
                       (or (is-eq (get permission-level permission) "full")
                           (is-eq (get permission-level permission) level)))
        false))

(define-read-only (can-access-record (patient principal) (accessor principal))
    (or (is-eq patient accessor)
        (has-permission patient accessor "read")
        (has-permission patient accessor "write")
        (has-permission patient accessor "full")))

(define-read-only (get-access-permissions (patient principal))
    (if (is-eq tx-sender patient)
        (ok (get-patient-permissions patient))
        ERR_NOT_AUTHORIZED))

(define-read-only (get-provider-info (provider principal))
    (map-get? healthcare-providers provider))

(define-read-only (get-total-records)
    (var-get total-records))

(define-read-only (get-total-patients)
    (var-get total-patients))

(define-read-only (get-access-log (log-id uint))
    (map-get? access-logs log-id))

(define-private (log-access (record-id uint) (accessor principal) (access-type (string-ascii 16)) (ip-hash (optional (string-ascii 64))))
    (let ((log-id (var-get next-log-id)))
        (map-set access-logs log-id {
            record-id: record-id,
            accessor: accessor,
            access-type: access-type,
            accessed-at: stacks-block-height,
            ip-hash: ip-hash
        })
        (var-set next-log-id (+ log-id u1))
        log-id))

(define-private (filter-records (patient principal))
    (list))

(define-private (get-patient-permissions (patient principal))
    (list))

(define-read-only (is-emergency-contact (patient principal) (contact principal))
    (match (map-get? patients patient)
        patient-data (is-eq (get emergency-contact patient-data) (some contact))
        false))

(define-read-only (get-record-count-by-patient (patient principal))
    (if (can-access-record patient tx-sender)
        (ok u0) ;; Simplified for demo
        ERR_ACCESS_DENIED))

(define-read-only (verify-record-integrity (record-id uint) (expected-hash (string-ascii 64)))
    (match (map-get? patient-records record-id)
        record (ok (is-eq (get record-hash record) expected-hash))
        ERR_RECORD_NOT_FOUND))

(define-public (register-pharmacy 
    (name (string-ascii 64))
    (license-number (string-ascii 32)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (map-get? pharmacies tx-sender)) ERR_ALREADY_EXISTS)
        (map-set pharmacies tx-sender {
            pharmacy-id: (var-get total-prescriptions),
            name: name,
            license-number: license-number,
            verified: true,
            registered-at: stacks-block-height
        })
        (ok true)))

(define-public (create-prescription 
    (patient principal)
    (medication (string-ascii 64))
    (dosage (string-ascii 32))
    (quantity uint)
    (max-refills uint)
    (expires-in-blocks uint)
    (instructions (string-ascii 256)))
    (let ((prescription-id (var-get next-prescription-id)))
        (asserts! (is-some (map-get? patients patient)) ERR_INVALID_PATIENT)
        (asserts! (is-some (map-get? healthcare-providers tx-sender)) ERR_NOT_AUTHORIZED)
        (asserts! (> quantity u0) ERR_INVALID_DATA)
        (asserts! (> expires-in-blocks u0) ERR_INVALID_DATA)
        
        (map-set prescriptions prescription-id {
            patient: patient,
            prescriber: tx-sender,
            medication: medication,
            dosage: dosage,
            quantity: quantity,
            refills-remaining: max-refills,
            max-refills: max-refills,
            issued-at: stacks-block-height,
            expires-at: (+ stacks-block-height expires-in-blocks),
            active: true,
            instructions: instructions
        })
        
        (var-set next-prescription-id (+ prescription-id u1))
        (var-set total-prescriptions (+ (var-get total-prescriptions) u1))
        (ok prescription-id)))

(define-public (fill-prescription 
    (prescription-id uint)
    (quantity-dispensed uint)
    (pharmacist principal))
    (let (
        (prescription (unwrap! (map-get? prescriptions prescription-id) ERR_PRESCRIPTION_NOT_FOUND))
        (fill-number (+ (- (get max-refills prescription) (get refills-remaining prescription)) u1))
    )
        (asserts! (is-some (map-get? pharmacies tx-sender)) ERR_INVALID_PHARMACY)
        (asserts! (get active prescription) ERR_PRESCRIPTION_EXPIRED)
        (asserts! (< stacks-block-height (get expires-at prescription)) ERR_PRESCRIPTION_EXPIRED)
        (asserts! (> (get refills-remaining prescription) u0) ERR_INSUFFICIENT_REFILLS)
        (asserts! (<= quantity-dispensed (get quantity prescription)) ERR_INVALID_DATA)
        
        (map-set prescription-fills (var-get next-log-id) {
            prescription-id: prescription-id,
            pharmacy: tx-sender,
            filled-at: stacks-block-height,
            quantity-dispensed: quantity-dispensed,
            pharmacist: pharmacist,
            fill-number: fill-number
        })
        
        (map-set prescriptions prescription-id 
            (merge prescription { refills-remaining: (- (get refills-remaining prescription) u1) }))
        
        (var-set next-log-id (+ (var-get next-log-id) u1))
        (ok true)))

(define-public (cancel-prescription (prescription-id uint))
    (let ((prescription (unwrap! (map-get? prescriptions prescription-id) ERR_PRESCRIPTION_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get prescriber prescription)) ERR_NOT_AUTHORIZED)
        (map-set prescriptions prescription-id 
            (merge prescription { active: false }))
        (ok true)))

(define-read-only (get-prescription (prescription-id uint))
    (let ((prescription (unwrap! (map-get? prescriptions prescription-id) ERR_PRESCRIPTION_NOT_FOUND)))
        (if (or (is-eq tx-sender (get patient prescription))
                (is-eq tx-sender (get prescriber prescription))
                (is-some (map-get? pharmacies tx-sender)))
            (ok prescription)
            ERR_ACCESS_DENIED)))

(define-read-only (get-patient-prescriptions (patient principal))
    (if (or (is-eq tx-sender patient)
            (can-access-record patient tx-sender))
        (ok (get-prescriptions-for-patient patient))
        ERR_ACCESS_DENIED))

(define-read-only (verify-prescription (prescription-id uint))
    (match (map-get? prescriptions prescription-id)
        prescription (ok {
            valid: (and (get active prescription) 
                       (< stacks-block-height (get expires-at prescription))
                       (> (get refills-remaining prescription) u0)),
            expires-at: (get expires-at prescription),
            refills-remaining: (get refills-remaining prescription)
        })
        ERR_PRESCRIPTION_NOT_FOUND))

(define-read-only (get-prescription-fills (prescription-id uint))
    (if (is-prescription-accessible prescription-id tx-sender)
        (ok (get-fills-for-prescription prescription-id))
        ERR_ACCESS_DENIED))

(define-read-only (get-pharmacy-info (pharmacy principal))
    (map-get? pharmacies pharmacy))

(define-read-only (get-total-prescriptions)
    (var-get total-prescriptions))

(define-private (is-prescription-accessible (prescription-id uint) (accessor principal))
    (match (map-get? prescriptions prescription-id)
        prescription (or (is-eq accessor (get patient prescription))
                        (is-eq accessor (get prescriber prescription))
                        (is-some (map-get? pharmacies accessor)))
        false))

(define-private (get-prescriptions-for-patient (patient principal))
    (list))

(define-private (get-fills-for-prescription (prescription-id uint))
    (list))

(define-private (is-valid-category (category (string-ascii 20)))
    (or (is-eq category "Labs") (is-eq category "Imaging") (is-eq category "Prescriptions")
        (is-eq category "Visits") (is-eq category "Notes") (is-eq category "TestResults")
        (is-eq category "Immunizations") (is-eq category "Allergies")))

(define-private (is-valid-priority (priority uint))
    (and (>= priority u1) (<= priority u5)))

(define-public (classify-record (record-id uint) (patient principal) (category (string-ascii 20)) (priority uint))
    (let ((record (unwrap! (map-get? patient-records record-id) ERR_RECORD_NOT_FOUND)))
        (asserts! (is-valid-category category) ERR_INVALID_CATEGORY)
        (asserts! (is-valid-priority priority) ERR_INVALID_PRIORITY)
        (asserts! (or (is-eq tx-sender patient) (has-permission patient tx-sender "read") (has-permission patient tx-sender "write")) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get patient record) patient) ERR_INVALID_PATIENT)
        (map-set record-classifications { record-id: record-id, patient: patient } {
            category: category,
            priority: priority
        })
        (ok true)))

(define-public (update-record-classification (record-id uint) (patient principal) (category (string-ascii 20)) (priority uint))
    (let ((existing (unwrap! (map-get? record-classifications { record-id: record-id, patient: patient }) ERR_NOT_CLASSIFIED)))
        (asserts! (is-valid-category category) ERR_INVALID_CATEGORY)
        (asserts! (is-valid-priority priority) ERR_INVALID_PRIORITY)
        (asserts! (or (is-eq tx-sender patient) (has-permission patient tx-sender "write")) ERR_NOT_AUTHORIZED)
        (map-set record-classifications { record-id: record-id, patient: patient } {
            category: category,
            priority: priority
        })
        (ok true)))

(define-read-only (get-record-category (record-id uint) (patient principal))
    (if (can-access-record patient tx-sender)
        (ok (map-get? record-classifications { record-id: record-id, patient: patient }))
        ERR_ACCESS_DENIED))

(define-read-only (get-records-by-category (patient principal) (category (string-ascii 20)))
    (if (can-access-record patient tx-sender)
        (if (is-valid-category category)
            (ok (list))
            ERR_INVALID_CATEGORY)
        ERR_ACCESS_DENIED))

(define-read-only (get-critical-records (patient principal))
    (if (can-access-record patient tx-sender)
        (ok (list))
        ERR_ACCESS_DENIED))

(define-public (register-medical-alert (patient principal) (alert-type uint) (severity uint) (substance (string-ascii 100)) (description (string-ascii 500)))
    (let
        (
            (provider tx-sender)
            (current-block stacks-block-height)
            (existing-count (default-to u0 (map-get? patient-alert-count patient)))
            (new-alert-id (+ existing-count u1))
            (type-count (default-to u0 (map-get? alert-type-count { patient: patient, alert-type: alert-type })))
        )
        (asserts! (is-some (map-get? healthcare-providers provider)) ERR_NOT_AUTHORIZED)
        (asserts! (can-access-record patient provider) ERR_ACCESS_DENIED)
        (asserts! (validate-alert-type alert-type) ERR_INVALID_ALERT_TYPE)
        (asserts! (validate-severity severity) ERR_INVALID_SEVERITY)
        (asserts! (> (len substance) u0) ERR_INVALID_DATA)
        (asserts! (> (len description) u0) ERR_INVALID_DATA)
        
        (map-set medical-alerts
            { patient: patient, alert-id: new-alert-id }
            {
                alert-type: alert-type,
                severity: severity,
                substance: substance,
                description: description,
                created-by: provider,
                created-at: current-block,
                updated-at: current-block,
                is-active: true
            }
        )
        
        (map-set patient-alert-count patient new-alert-id)
        (map-set alert-type-index
            { patient: patient, alert-type: alert-type, index: (+ type-count u1) }
            { alert-id: new-alert-id }
        )
        (map-set alert-type-count
            { patient: patient, alert-type: alert-type }
            (+ type-count u1)
        )
        
        (var-set next-global-alert-id (+ (var-get next-global-alert-id) u1))
        (log-access new-alert-id provider "alert-create" none)
        (ok new-alert-id)
    )
)

(define-public (update-medical-alert (patient principal) (alert-id uint) (severity uint) (description (string-ascii 500)))
    (let
        (
            (provider tx-sender)
            (current-block stacks-block-height)
            (alert-data (unwrap! (map-get? medical-alerts { patient: patient, alert-id: alert-id }) ERR_ALERT_NOT_FOUND))
        )
        (asserts! (is-some (map-get? healthcare-providers provider)) ERR_NOT_AUTHORIZED)
        (asserts! (can-access-record patient provider) ERR_ACCESS_DENIED)
        (asserts! (validate-severity severity) ERR_INVALID_SEVERITY)
        (asserts! (> (len description) u0) ERR_INVALID_DATA)
        
        (map-set medical-alerts
            { patient: patient, alert-id: alert-id }
            (merge alert-data {
                severity: severity,
                description: description,
                updated-at: current-block
            })
        )
        (log-access alert-id provider "alert-update" none)
        (ok true)
    )
)

(define-public (deactivate-medical-alert (patient principal) (alert-id uint))
    (let
        (
            (provider tx-sender)
            (current-block stacks-block-height)
            (alert-data (unwrap! (map-get? medical-alerts { patient: patient, alert-id: alert-id }) ERR_ALERT_NOT_FOUND))
        )
        (asserts! (is-some (map-get? healthcare-providers provider)) ERR_NOT_AUTHORIZED)
        (asserts! (can-access-record patient provider) ERR_ACCESS_DENIED)
        (asserts! (get is-active alert-data) ERR_INVALID_ALERT_STATUS)
        
        (map-set medical-alerts
            { patient: patient, alert-id: alert-id }
            (merge alert-data {
                is-active: false,
                updated-at: current-block
            })
        )
        (log-access alert-id provider "alert-deactivate" none)
        (ok true)
    )
)

(define-public (reactivate-medical-alert (patient principal) (alert-id uint))
    (let
        (
            (provider tx-sender)
            (current-block stacks-block-height)
            (alert-data (unwrap! (map-get? medical-alerts { patient: patient, alert-id: alert-id }) ERR_ALERT_NOT_FOUND))
        )
        (asserts! (is-some (map-get? healthcare-providers provider)) ERR_NOT_AUTHORIZED)
        (asserts! (can-access-record patient provider) ERR_ACCESS_DENIED)
        (asserts! (not (get is-active alert-data)) ERR_INVALID_ALERT_STATUS)
        
        (map-set medical-alerts
            { patient: patient, alert-id: alert-id }
            (merge alert-data {
                is-active: true,
                updated-at: current-block
            })
        )
        (log-access alert-id provider "alert-reactivate" none)
        (ok true)
    )
)

(define-private (validate-alert-type (alert-type uint))
    (and
        (>= alert-type u1)
        (<= alert-type u4)
    )
)

(define-private (validate-severity (severity uint))
    (and
        (>= severity u1)
        (<= severity u4)
    )
)

(define-read-only (get-medical-alert (patient principal) (alert-id uint))
    (map-get? medical-alerts { patient: patient, alert-id: alert-id })
)

(define-read-only (get-patient-alert-count (patient principal))
    (default-to u0 (map-get? patient-alert-count patient))
)

(define-read-only (get-alerts-by-type (patient principal) (alert-type uint))
    (let
        (
            (type-count (default-to u0 (map-get? alert-type-count { patient: patient, alert-type: alert-type })))
        )
        (ok type-count)
    )
)

(define-read-only (check-drug-interaction (patient principal) (substance (string-ascii 100)))
    (let
        (
            (total-alerts (get-patient-alert-count patient))
        )
        (ok (> total-alerts u0))
    )
)

(define-read-only (get-critical-alerts (patient principal))
    (let
        (
            (count (get-patient-alert-count patient))
        )
        (if (> count u0)
            (ok count)
            (ok u0)
        )
    )
)

(define-read-only (has-active-alerts (patient principal))
    (> (get-patient-alert-count patient) u0)
)
