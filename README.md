## Intent

Define a production-ready, offline-first encrypted document vault architecture in Flutter with concrete tech stack, data flows, and security boundaries.

---

# 1. System Architecture (Non-Negotiable Invariants)

## Core Principle

Everything is encrypted before leaving memory boundaries.

No plaintext persistence outside RAM during active operations.

---

## High-Level Architecture

```text
┌──────────────────────────────┐
│        Flutter UI            │
└────────────┬─────────────────┘
             │
┌────────────▼─────────────────┐
│     Application Layer        │
│  (Vault Controller / State)  │
└────────────┬─────────────────┘
             │
┌────────────▼─────────────────┐
│      Domain Layer            │
│  - Vault Service             │
│  - Auth Service              │
│  - Import/Export Service     │
└────────────┬─────────────────┘
             │
┌────────────▼─────────────────┐
│   Crypto Layer (CRITICAL)    │
│  - Key Derivation (Argon2)   │
│  - AES-256-GCM Encryption    │
│  - Random Generator          │
└────────────┬─────────────────┘
             │
┌────────────▼─────────────────┐
│ Storage Layer                │
│ - Encrypted files (.enc)     │
│ - SQLCipher metadata DB      │
│ - Secure storage (keys only) │
└──────────────────────────────┘
```

---

# 2. Tech Stack (Flutter + Native Bridge where needed)

## Flutter Core

- `flutter` (obvious)
    
- `flutter_bloc` (or Riverpod, but Riverpod is less boilerplate-heavy)
    
- `freezed` (immutable state models, will be used for release only)
    
- `json_serializable`(will be used for release only)
    

---

## Cryptography (Critical Layer)

### Recommended

- `cryptography` (Dart package)
    

Why:

- Clean API
    
- Modern primitives
    
- Safer than raw PointyCastle usage
    

### Native fallback (optional hardening)

- Android: Jetpack Security / Keystore
    
- iOS: Keychain + CryptoKit (via platform channels if needed)
    

---

## Key Storage

- `flutter_secure_storage`
    

Backed by:

- Android Keystore
    
- iOS Keychain
    

Use ONLY for:

- Vault master key (encrypted form)
    
- salt metadata
    
- config flags
    

Never store:

- documents
    
- decrypted keys in persistent storage
    

---

## Authentication

- `local_auth` (Biometric authentication)
    

Backed by:

- Android BiometricPrompt
    
- iOS LocalAuthentication
    

Role:

- Unlock vault key, not replace password
    

---

## Database (Encrypted Metadata)

### Required

- `sqflite_sqlcipher` OR `sqlcipher_flutter_libs`
    

This gives:

- Encrypted SQLite DB
    
- Searchable metadata (still encrypted at rest)
    

---

## File Storage

- `path_provider`
    
- `dart:io`
    

Store:

```text
/vault/
  docs/
  thumbs/
  cache/ (temporary only)
```

All `.enc`

---

## File Picking / Import

- `file_picker`
    

---

## Background safety / screen protection

- `flutter_windowmanager` (Android FLAG_SECURE)
    
- iOS: handled via native config
    

---

## Utilities

- `uuid`
    
- `crypto` (for hashes if needed, but not for encryption)
    
- `path`
    

---

# 3. Cryptographic Design (Core Security Model)

## Key Hierarchy

```text
Master Password
      ↓
Argon2id (salted)
      ↓
Master Key (KEK)
      ↓
Vault Key (DEK)
      ↓
AES-256-GCM encryption for files
```

### Why 2 keys?

- Master key: derived from password
    
- Vault key: rotates without changing password
    

---

## Encryption Standard

- AES-256-GCM
    

Properties:

- Confidentiality
    
- Integrity (auth tag)
    
- Tamper detection
    

---

## Password Derivation

Use:

- Argon2id (NOT SHA256)
    

Config:

```text
Memory: 64–128 MB
Iterations: 2–3
Parallelism: 2
```

---

# 4. Data Model

## Metadata (SQLCipher DB)

```json
Document {
  id: UUID,
  title: String,
  type: String,
  encryptedFilePath: String,
  thumbnailPath: String,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

Everything inside DB is encrypted at rest.

---

## File Format

Each document:

```text
file.enc
 ├── header (version, algorithm)
 ├── nonce
 ├── ciphertext
 ├── auth tag
```

---

# 5. Core Workflows

---

## 5.1 First Launch (Vault Creation)

```text
User enters password
↓
Generate salt
↓
Argon2id(password, salt)
↓
Create Master Key
↓
Generate Vault Key
↓
Encrypt Vault Key with Master Key
↓
Store in secure storage
↓
Initialize encrypted DB
```

---

## 5.2 Unlock Flow

```text
User enters password / biometrics
↓
Derive Master Key (Argon2id)
↓
Decrypt Vault Key
↓
Unlock session (in memory only)
```

Vault key never touches disk in plaintext.

---

## 5.3 Document Import

```text
Pick file
↓
Copy to temp directory
↓
Read bytes
↓
Encrypt (AES-GCM + Vault Key)
↓
Write .enc file
↓
Delete temp file
↓
Insert metadata into SQLCipher DB
```

Critical:

- temp cleanup must be guaranteed
    

---

## 5.4 Document Open

```text
Read .enc file
↓
Decrypt in memory
↓
Render (image/pdf viewer)
↓
Clear memory reference ASAP
```

No caching plaintext.

---

## 5.5 Export (Backup)

```text
Collect metadata + encrypted files
↓
Package into archive
↓
Encrypt archive using:
  backup password → Argon2id
↓
Output .vaultbackup
```

Backup is independent of vault password.

---

## 5.6 Restore

```text
Select .vaultbackup
↓
Enter backup password
↓
Decrypt archive
↓
Rebuild DB + file structure
```

---

# 6. Security Controls

## Mandatory Controls

### Auto Lock

- Background app → lock
    
- Idle timeout → lock
    

---

### Screenshot Protection

Android:

```kotlin
FLAG_SECURE
```

---

### Root / Jailbreak Detection (optional warning)

- advisory only (not blocking)
    

---

### Memory Safety

- Avoid long-lived plaintext objects
    
- Explicit nulling after use
    

---

# 7. Flutter State Design

Keep state simple:

```text
VaultState
 ├── locked/unlocked
 ├── documents list
 ├── selected document
 ├── loading states
```

Do NOT mix crypto logic in UI.

---

# 8. Native Integration (When Needed)

## Android

- Keystore-backed encryption key protection
    
- FLAG_SECURE enforcement
    

## iOS

- Keychain storage
    
- Secure enclave when available
    

Only use platform channels for:

- hardened key storage
    
- screen security
    

Not for app logic.

---

# 9. Performance Considerations

## Bottlenecks

### Large file encryption

Solution:

- chunk-based encryption (optional later)
    

### SQLCipher queries

Solution:

- indexed metadata only
    

### Memory spikes

Solution:

- stream processing instead of full file load (future optimization)
    

---

# 10. Version Roadmap

## V1 (Offline Vault)

- Everything above except:
    
    - cloud sync
        
    - QR sharing
        
    - multi-device identity
        

---

## V2 (Cloud Sync Optional)

- End-to-end encryption sync
    
- device pairing
    
- conflict resolution
    

---

## V3 (Identity Layer)

- verifiable credentials
    
- QR-based selective disclosure
    

---

# 11. Biggest Engineering Risks

### 1. Key mishandling (Critical)

Likelihood: High

### 2. Temp file leakage (Major)

Likelihood: High

### 3. Weak password choice (Major)

Likelihood: Guaranteed

### 4. SQLCipher misuse (Moderate)

Likelihood: Medium

### 5. Over-engineering early (Strategic failure)

Likelihood: High

---

# Final Recommendation

Build exactly this stack:

### Core Stack

- Flutter
    
- Riverpod
    
- cryptography
    
- flutter_secure_storage
    
- local_auth
    
- sqflite_sqlcipher
    
- file_picker
    
- path_provider
    

### Crypto

- AES-256-GCM
    
- Argon2id
    

### Storage

- encrypted files on disk
    
- SQLCipher metadata DB
    
- secure storage only for wrapped keys
    

---

# Concrete Decision

Implement an offline-first vault with:

- Argon2id-derived master key
    
- AES-256-GCM encrypted documents
    
- SQLCipher encrypted metadata
    
- biometric unlock via native APIs
    
- encrypted import/export system
    

---

# What to Measure

- encryption/decryption time per 10MB file
    
- vault unlock latency
    
- import/export success rate
    
- crash recovery after interrupted import
    
- memory peak during encryption
    

---

# Remaining Risks

- user password weakness (cannot solve fully)
    
- device compromise (root/jailbreak)
    
- Flutter plugin vulnerabilities
    
- accidental plaintext leaks in debug logs
    

---

# Tradeoff Judgment

You are trading:

- complexity of cloud identity systems ❌
    
- for deterministic local security model ✔️
    

This is the correct move for a solo developer.

---

If you execute this cleanly, you don’t get a “feature app.”  
You get a legitimate security product that people can actually trust offline.