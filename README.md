# 🏥 HealthLedger - Immutable Patient Records

A decentralized, secure, and immutable patient health record management system built on the Stacks blockchain using Clarity smart contracts.

## 🎯 Overview

HealthLedger provides a trustless, transparent, and secure way to store and manage patient health records with granular access control. Each record is immutably stored on the blockchain while maintaining patient privacy through permission-based access.

## ✨ Key Features

- 🔒 **Immutable Records** - Patient records are permanently stored and cannot be altered
- 🔐 **Access Control** - Granular permission system for healthcare providers
- 👤 **Patient Sovereignty** - Patients control who can access their records
- 🚨 **Emergency Access** - Emergency contacts can access records during critical situations
- 📝 **Audit Trail** - Complete access logging for transparency and compliance
- 🏥 **Provider Verification** - Healthcare provider registration and verification system
- 🔍 **Data Integrity** - Cryptographic hash verification for record authenticity

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Immutable-Patient-Records
```

2. Check contract compilation:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📋 Contract Functions

### Patient Management

#### `register-patient`
Register a new patient in the system.

**Parameters:**
- `emergency-contact` (optional principal) - Emergency contact principal

**Returns:** Patient ID

```clarity
(contract-call? .HealthLedger register-patient (some 'SP1EMERGENCY))
```

### Record Management

#### `create-record`
Create a new medical record for a patient.

**Parameters:**
- `patient` (principal) - Patient's address
- `record-hash` (string-ascii 64) - Cryptographic hash of the record
- `record-type` (string-ascii 32) - Type of medical record
- `encrypted` (bool) - Whether the record is encrypted
- `metadata` (string-ascii 256) - Additional metadata

```clarity
(contract-call? .HealthLedger create-record 
    'SP1PATIENT 
    "abc123hash..." 
    "blood-test" 
    true 
    "Regular checkup")
```

### Access Control

#### `grant-access`
Grant access permissions to healthcare providers or other entities.

**Permission Levels:**
- `"read"` - View records only
- `"write"` - Create new records
- `"full"` - Read and write access

```clarity
(contract-call? .HealthLedger grant-access 
    'SP1DOCTOR 
    "read" 
    (some u1000)) ;; Expires in 1000 blocks
```

#### `revoke-access`
Revoke previously granted access permissions.

```clarity
(contract-call? .HealthLedger revoke-access 'SP1DOCTOR)
```

#### `emergency-access`
Allow emergency contacts to access records during critical situations.

```clarity
(contract-call? .HealthLedger emergency-access 'SP1PATIENT)
```

### Healthcare Providers

#### `register-provider`
Register a healthcare provider (admin only).

```clarity
(contract-call? .HealthLedger register-provider "Cardiology")
```

## 📊 Read-Only Functions

### Patient Information

- `get-patient-info` - Retrieve patient registration details
- `get-patient-records` - List all records for a patient
- `get-record-count-by-patient` - Count records for a specific patient

### Record Access

- `get-record` - Retrieve a specific record (with access control)
- `verify-record-integrity` - Verify record hash integrity
- `has-permission` - Check if accessor has specific permission

### System Stats

- `get-total-records` - Total number of records in the system
- `get-total-patients` - Total number of registered patients
- `get-access-log` - Retrieve access log entry

## 🛡️ Security Features

### Permission System
- **Patient Control**: Patients have full control over their data
- **Time-bound Access**: Permissions can have expiration dates  
- **Emergency Override**: Emergency contacts can access records during crises
- **Audit Trail**: All access attempts are logged

### Data Integrity
- **Hash Verification**: Records are verified using cryptographic hashes
- **Immutable Storage**: Once stored, records cannot be modified
- **Access Logging**: Complete audit trail of all data access

## 🏥 Use Cases

### For Patients 👤
- Control who accesses your medical records
- Grant temporary access to specialists
- Maintain complete ownership of health data
- Emergency access for critical situations

### For Healthcare Providers 🩺
- Secure access to patient records with proper permissions
- Maintain treatment history across different providers
- Comply with healthcare privacy regulations
- Verify record authenticity and integrity

### For Healthcare Systems 🏥
- Interoperability between different healthcare providers
- Reduced administrative overhead
- Enhanced security and privacy compliance
- Transparent audit trails for regulatory requirements

## 📈 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR_NOT_AUTHORIZED | User not authorized for this action |
| u101 | ERR_INVALID_PATIENT | Patient not found or invalid |
| u102 | ERR_RECORD_NOT_FOUND | Requested record does not exist |
| u103 | ERR_ALREADY_EXISTS | Entity already exists |
| u104 | ERR_INVALID_PERMISSION | Invalid permission level |
| u105 | ERR_ACCESS_DENIED | Access denied to requested resource |
| u106 | ERR_INVALID_DATA | Invalid or malformed data |

## 🔧 Development

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy --network testnet
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on [Stacks blockchain](https://stacks.org)
- Developed with [Clarity](https://clarity-lang.org)
- Powered by [Clarinet](https://github.com/hirosystems/clarinet)

---

**⚠️ Disclaimer**: This is a demonstration project. For production use in healthcare environments, ensure compliance with applicable regulations like HIPAA, GDPR, and local healthcare data protection laws.
