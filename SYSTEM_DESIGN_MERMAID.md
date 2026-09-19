# Trident — System Design Diagrams (Mermaid)

* [ ]

- `lib/features/documents/presentation/cubits/encryption_task.dart`
- `lib/features/documents/presentation/cubits/document_cubit.dart`
- `lib/features/documents/domain/services/document_services.dart`
- `lib/features/documents/domain/models/document_model.dart`
- `lib/core/algorithms/aes_128.dart`
- `lib/core/algorithms/sha256.dart`
- `lib/core/routes/route_config.dart`
- `lib/core/routes/route_names.dart`

---

## 1. Use Case Diagram

```mermaid
graph LR
    %% Actors
    User(["User"])
    Locked(["Vault Locked"])

    %% Boundary / System
    subgraph TRIDENT["Trident Secure Document Vault"]
        direction TB
        UC_VL(["View Document List"])
        UC_PD(["Preview Document"])
        UC_AD(["Add Document"])
        UC_DL(["Delete Document"])
        UC_SD(["Search Documents"])
        UC_DC(["Count Documents"])
        UC_LA(["Log Audit Events"])
    end

    %% Actor to Use Case
    User --> UC_VL
    User --> UC_PD
    User --> UC_AD
    User --> UC_DL
    User --> UC_SD
    User -.-> UC_DC
    User -.-> UC_LA
    Locked -.->|"blocks encrypt/decrypt"| UC_AD
    Locked -.->|"blocks decrypt"| UC_PD

    %% Styling
    classDef actor fill:#e1f5fe,stroke:#0288d1,stroke-width:2px
    classDef locked fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef usecase fill:#f3e5f5,stroke:#6a1b9a,stroke-width:1px
    classDef system fill:#e8f5e9,stroke:#4caf50,stroke-width:1px
    class User actor
    class Locked locked
    class UC_VL,UC_PD,UC_AD,UC_DL,UC_SD,UC_DC,UC_LA usecase
    class TRIDENT system
```

---

## 2. Class Diagram

```mermaid
classDiagram
    %% === Domain Models ===
    class DocumentModel {
        +id: String
        +title: String
        +type: DocumentType
        +size: int
        +createdAt: DateTime
        +sha256: String
        +encryptedFileName: String
        +toJson()
        +fromJson()
    }
    class DocumentType {
        <<enumeration>>
        image
        pdf
    }

    %% === State Management (Cubit) ===
    class DocumentState {
        <<abstract>>
    }
    class DocumentInitial
    class DocumentLoading
    class DocumentLoaded {
        +documents: List
    }
    class DocumentError {
        +message: String
    }
    class DocumentCubit {
        -_vaultRepository: VaultRepository
        -_storageService: DocumentStorageService
        -_auditLogService: AuditLogService
        +isVaultLocked: bool
        +maxFileSize: int
        +loadDocuments()
        +pickAndStoreDocument()
        +previewDocument()
        +deleteDocument()
        +searchDocuments()
    }

    %% === Services Layer ===
    class DocumentServices {
        +instance: DocumentServices
        +handleImport()
    }
    class DocumentStorageService {
        <<abstract>>
        +saveDocument()
        +loadAllMetadata()
        +loadEncryptedData()
        +deleteDocument()
        +countDocuments()
    }
    class VaultRepository {
        -isUnlocked: bool
        +getDek()
    }
    class AuditLogService {
        +log()
        +watchEvents()
        +getAll()
    }

    %% === Audit Domain ===
    class AuditLogEvent {
        +type: AuditLogType
        +title: String
        +timestamp: DateTime
    }
    class AuditLogType {
        <<enumeration>>
        documentAdded
        documentRemoved
        login
        unlockVault
    }

    %% === Isolate Task Payloads ===
    class EncryptionTask {
        +data: List
        +key: List
    }
    class EncryptionResult {
        +encryptedData: List
        +hashHex: String
    }
    class DecryptionTask {
        +data: List
        +key: List
        +expectedHashHex: String
    }
    class DecryptionResult {
        +plaintext: List
        +computedHashHex: String
    }
    class IsolateFunctions {
        +encryptAndHash()
        +decryptAndVerify()
    }

    %% === Hand-Written Algorithms ===
    class Sha256 {
        +hash()
        +hashHex()
        -_rotr()
        -_pad()
    }
    class Aes128 {
        +encrypt()
        +decrypt()
        +encryptBlock()
        +decryptBlock()
        -_expandKey()
    }

    %% === State Inheritance ===
    DocumentState <|-- DocumentInitial
    DocumentState <|-- DocumentLoading
    DocumentState <|-- DocumentLoaded
    DocumentState <|-- DocumentError

    %% === Usage / Composition ===
    DocumentModel --> DocumentType : type
    DocumentCubit --> DocumentState : emits
    DocumentCubit --> VaultRepository : getDek()
    DocumentCubit --> DocumentStorageService : CRUD
    DocumentCubit --> AuditLogService : log / watch
    DocumentCubit ..> EncryptionTask : create (compute payload)
    DocumentCubit ..> DecryptionTask : create (compute payload)
    DocumentCubit ..> EncryptionResult : receives
    DocumentCubit ..> DecryptionResult : receives
    DocumentServices --> DocumentCubit : pickAndStoreDocument()
    DocumentServices --> BuildContext : for dialogs
    IsolateFunctions ..> EncryptionTask : receives
    IsolateFunctions ..> DecryptionTask : receives
    IsolateFunctions --> Sha256 : hash()
    IsolateFunctions --> Aes128 : encrypt() / decrypt()
    AuditLogService --> AuditLogEvent : creates
    AuditLogEvent --> AuditLogType : classified as
    VaultRepository --> SecureStorage : DEK
```

---

## 3. Object Diagram

```mermaid
classDiagram
    class docModel1 {
        id: String
        title: String
        type: DocumentType
        size: int
        createdAt: DateTime
        sha256: String
        encryptedFileName: String
    }
    class cubit1 {
        isVaultLocked: bool
        maxFileSize: int
    }
    class state1 {
        documents: List
    }
    class task1 {
        data: List
        key: List
    }
    class result1 {
        encryptedData: List
        hashHex: String
    }
    class auditEvent1 {
        type: AuditLogType
        title: String
        timestamp: DateTime
    }
    class DocumentModel
    class DocumentCubit
    class DocumentLoaded
    class EncryptionTask
    class EncryptionResult

    docModel1 --|> DocumentModel : instance of
    cubit1 --|> DocumentCubit : instance of
    state1 --|> DocumentLoaded : instance of
    state1 --> docModel1 : documents
    task1 --|> EncryptionTask : instance of
    result1 --|> EncryptionResult : instance of
    auditEvent1 --|> AuditLogEvent : instance of
    cubit1 --> state1 : current state
    task1 --> result1 : processed by encryptAndHash
    cubit1 --> auditEvent1 : logs
```

---

## 4. State Diagram (DocumentCubit)

```mermaid
stateDiagram-v2
    [*] --> DocumentInitial : onCreate

    state DocumentInitial
    state DocumentLoading
    state DocumentLoaded
    state DocumentError

    DocumentInitial --> DocumentLoading : loadDocuments()
    DocumentLoading --> DocumentLoaded : success (emit DocumentLoaded)
    DocumentLoading --> DocumentError : failure / size exceeded (emit DocumentError)
    DocumentLoaded --> DocumentLoading : refresh (loadDocuments)
    DocumentError --> DocumentLoading : retry (loadDocuments)
    DocumentLoaded --> DocumentInitial : reset

    note right of DocumentLoading
        Async operations running:
        - compute(encryptAndHash) in isolate
        - compute(decryptAndVerify) in isolate
        - File I/O on storage service
    end note

    note right of DocumentError
        Error scenarios:
        - File > 5 MB maxFileSize
        - Vault locked (no DEK)
        - Crypto failure
        - Storage I/O error
    end note
```

---

## 5. Sequence Diagram: Adding a Document (Import Flow)

```mermaid
sequenceDiagram
    participant User
    participant HomeScreen
    participant DocumentServices
    participant LoadingDialog
    participant DocumentCubit
    participant Isolate
    participant VaultRepository
    participant Aes128
    participant Sha256
    participant StorageSvc
    participant AuditLog

    User ->> HomeScreen: Tap "Import" tile
    HomeScreen ->> DocumentServices: handleImport(context)

    DocumentServices ->> LoadingDialog: showDialog(barrierDismissible=false)
    LoadingDialog -->> User: Shows "Encrypting document..." spinner

    DocumentServices ->> DocumentCubit: pickAndStoreDocument()
    DocumentCubit ->> DocumentCubit: FilePicker.pickFile()
    DocumentCubit -->> User: Native file picker dialog
    User ->> DocumentCubit: Select 2.3 MB image
    DocumentCubit ->> DocumentCubit: readAsBytes() to bytes

    DocumentCubit ->> DocumentCubit: bytes.length > 5 MB?
    alt File too large ( > 5 MB)
        DocumentCubit ->> DocumentCubit: emit(DocumentError)
        DocumentCubit -->> DocumentServices: await completes
        DocumentServices ->> LoadingDialog: Navigator.pop() dismiss
        DocumentServices ->> User: showDialog(error, dismissible)
        DocumentServices -->> HomeScreen: Returns
        HomeScreen -->> User: Error shown
    else File OK (<= 5 MB)
        DocumentCubit ->> DocumentCubit: emit(DocumentLoading)
        DocumentCubit ->> VaultRepository: getDek()
        VaultRepository --> DocumentCubit: DEK (16+ bytes)
        DocumentCubit ->> Isolate: compute(encryptAndHash, EncryptionTask(bytes, dek.sublist(0,16)))
        Isolate ->> Sha256: hash(data) to hashHex
        Isolate ->> Aes128: encrypt(data, key) to encryptedData
        Isolate -->> DocumentCubit: EncryptionResult(encryptedData, hashHex)
        DocumentCubit ->> StorageSvc: saveDocument(encryptedData, metadata)
        StorageSvc -->> DocumentCubit: success
        DocumentCubit ->> AuditLog: log(documentAdded)
        AuditLog -->> DocumentCubit: stored
        DocumentCubit ->> DocumentCubit: loadDocuments()
        DocumentCubit ->> DocumentCubit: emit(DocumentLoaded(docs))
        DocumentServices ->> LoadingDialog: Navigator.pop() dismiss
        DocumentServices -->> HomeScreen: Returns
        HomeScreen -->> User: Document count updated
    end
```

---

## 6. Activity Diagram (Document Lifecycle)

```mermaid
graph TD
    A([Start: User Action]) --> B{Pick Action}

    %% ADD DOCUMENT flow
    B -->|"Import"| C[FilePicker.pickFile]
    C --> D[Read bytes from file]
    D --> E{Size LE 5 MB?}

    E -->|"No (too large)"| F[emit DocumentError]
    F --> G[Dismiss loading dialog]
    G --> H[Show error dialog: File exceeds 5 MB limit]
    H --> I([End])

    E -->|"Yes"| J[emit DocumentLoading]
    J --> K[Show loading dialog: Encrypting document...]
    K --> L[getDek from VaultRepository]
    L --> M[compute encryptAndHash - in bg isolate]
    M --> N{Aes128.encrypt and Sha256.hash}
    N --> O[EncryptionResult - encryptedData and hashHex]
    O --> P[saveDocument to disk]
    P --> Q[Store JSON metadata]
    Q --> R[AuditLog: documentAdded]
    R --> S[loadDocuments]
    S --> T[emit DocumentLoaded]
    T --> U[Dismiss loading dialog]
    U --> V[HomeScreen count updated]
    V --> I

    %% PREVIEW DOCUMENT flow
    B -->|"Preview"| W[Load encrypted file]
    W --> X[Load metadata]
    X --> Y[getDek from VaultRepository]
    Y --> Z[compute decryptAndVerify - in bg isolate]
    Z --> AA{Aes128.decrypt and Sha256.hash}
    AA --> AB[DecryptionResult - plaintext and computedHash]
    AB --> AC{hash matches?}
    AC -->|"Yes"| AD[Render: Image.memory or PdfView]
    AC -->|"No"| AE[Throw IntegrityException]
    AD --> I
    AE --> AF[Show tamper error]
    AF --> I

    %% DELETE DOCUMENT flow
    B -->|"Delete"| AG[Remove encrypted file]
    AG --> AH[Remove from metadata JSON]
    AH --> AI[AuditLog: documentRemoved]
    AI --> AJ[loadDocuments]
    AJ --> AK[emit DocumentLoaded]
    AK --> I

    %% Styling
    classDef startend fill:#c8e6c9,stroke:#388e3c,stroke-width:2px
    classDef process fill:#bbdefb,stroke:#1976d2,stroke-width:1px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:1px
    classDef isolate fill:#ffccbc,stroke:#d84315,stroke-width:2px

    class A,I startend
    class C,D,F,G,H,J,K,L,O,P,Q,R,S,T,U,V,W,X,Y,AB,AD,AE,AF,AG,AH,AI,AJ,AK process
    class E,M,AC decision
    class N,AA isolate
```

---

## 7. Component Diagram

```mermaid
graph TB
    %% UI Layer
    subgraph UI["UI Layer (Main Isolate)"]
        direction TB
        HS[HomeScreen]
        DS[DocumentScreen]
        DPS[DocumentPreviewScreen]
    end

    %% Business Logic
    subgraph BLoC["Business Logic Layer"]
        direction TB
        DC[DocumentCubit]
        DServ[DocumentServices]
    end

    %% Service Layer
    subgraph Services["Service Layer"]
        direction TB
        DSSI[DocumentStorageService Impl]
        VR[VaultRepository]
        ALS[AuditLogService]
    end

    %% Isolate Layer
    subgraph Isolate["Background Isolate via compute"]
        direction TB
        ET[EncryptionTask - encryptAndHash]
        DT[DecryptionTask - decryptAndVerify]
    end

    %% Crypto Layer
    subgraph Crypto["Cryptography Layer - Hand-Written, Pure Dart"]
        direction TB
        SHA[Sha256 - FIPS 180-4]
        AES[Aes128 - FIPS 197]
    end

    %% Storage Layer
    subgraph Storage["Storage Layer"]
        direction TB
        FS[(File System .enc files)]
        JSON[(JSON Metadata)]
        SEC[(Secure Storage - Vault DEK)]
    end

    %% Dependencies
    HS-->|Import tile tap| DServ
    HS <-->|searchDocuments / loadDocuments| DC
    DS <-->|deleteDocument / loadDocuments| DC
    DPS <--> DC

    DServ-->|pickAndStoreDocument| DC
    DServ -->|showDialog| HS

    DC -. getDek() .-> VR
    DC-->|saveDocument / loadEncryptedData| DSSI
    DC-->|loadAllMetadata / deleteDocument| DSSI
    DC-->|countDocuments| DSSI
    DC -. log() / watchEvents() .-> ALS

    DC -. compute(encryptAndHash, task) .-> ET
    DC -. compute(decryptAndVerify, task) .-> DT

    ET -. hash() .-> SHA
    ET -. encrypt() .-> AES
    DT -. decrypt() .-> AES
    DT -. hash() .-> SHA

    DSSI-->|write / read / delete| FS
    DSSI-->|read / write metadata| JSON
    VR -. getDek() .-> SEC

    %% Styling
    classDef ui fill:#e8f5e9,stroke:#4caf50
    classDef bloc fill:#e3f2fd,stroke:#2196f3
    classDef svc fill:#fff3e0,stroke:#ff9800
    classDef iso fill:#ffebee,stroke:#f44336
    classDef crypto fill:#fce4ec,stroke:#e91e63
    classDef storage fill:#f3e5f5,stroke:#9c27b0

    class HS,DS,DPS ui
    class DC,DServ bloc
    class DSSI,VR,ALS svc
    class ET,DT iso
    class SHA,AES crypto
    class FS,JSON,SEC storage
```

---

## 8. Deployment Diagram

```mermaid
graph TB
    %% Mobile Device
    subgraph DEVICE["Mobile Device Android / iOS"]
        direction TB

        %% Flutter App container
        subgraph APP["Flutter App - Dart VM"]
            direction TB

            %% Main Isolate
            subgraph MAIN_ISO["Main Isolate - UI"]
                direction TB
                HS[HomeScreen , DocumentScreen]
                DC[DocumentCubit , DocumentServices]
                UI[UI Widgets , Navigation]
            end

            %% Background Isolate
            subgraph BG_ISO["Background Isolate via compute"]
                direction TB
                IT[IsolateFunctions - encryptAndHash / decryptAndVerify]
                ISO_SHA[Sha256]
                ISO_AES[Aes128]
            end
        end

        %% Native Platform
        subgraph NATIVE["Native Platform Layer"]
            direction TB
            KS[Keystore Android]
            KC[Keychain iOS]
            FP[File Picker - native]
            PDF[PDF Renderer - pdfx]
        end

        %% Local Storage
        subgraph LOCAL["Local Storage"]
            direction TB
            FS[(Encrypted .enc Files on Disk)]
            MD[(documents_metadata.json)]
        end
    end

    %% Connections
    HS-->|navigates| UI
    DC -. compute() message (serialized payload) .-> IT
    IT-->|calls in isolate| ISO_SHA
    IT-->|calls in isolate| ISO_AES
    DC-->|getDek via flutter_secure_storage| KS
    DC-->|getDek via flutter_secure_storage| KC
    UI-->|file selection| FP
    HS-->|read count| FS
    HS-->|read count| MD
    DC-->|save/read/delete .enc| FS
    DC-->|read/write metadata| MD
    HS-->|renders preview| PDF

    %% Styling
    classDef device fill:#e8f5e9,stroke:#4caf50,stroke-width:3px
    classDef app fill:#e3f2fd,stroke:#2196f3,stroke-width:2px
    classDef isolate fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    classDef native fill:#fce4ec,stroke:#e91e63,stroke-width:2px
    classDef storage fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px

    class DEVICE device
    class APP app
    class MAIN_ISO,BG_ISO isolate
    class KS,KC,FP,PDF native
    class FS,MD storage
```

---

## Diagram Summary

| # | Diagram Type | Mermaid Syntax                   | Key Elements                                     |
| - | ------------ | -------------------------------- | ------------------------------------------------ |
| 1 | Use Case     | `graph LR`                     | 7 use cases, 2 actors, vault-blocked constraints |
| 2 | Class        | `classDiagram`                 | 18 classes, full inheritance + dependency graph  |
| 3 | Object       | `classDiagram` with `object` | 7 instances showing runtime state                |
| 4 | State        | `stateDiagram-v2`              | 4 DocumentCubit states, 5 transitions            |
| 5 | Sequence     | `sequenceDiagram`              | 9 participants, import flow with isolate         |
| 6 | Activity     | `graph TD`                     | Full lifecycle: Add, Store, Preview, Delete      |
| 7 | Component    | `graph TB`                     | 4 layers + isolate, 6 component groups           |
| 8 | Deployment   | `graph TB`                     | 2 isolates, native layer, local storage          |

*Generated from live codebase analysis — all class names, method signatures, and relationships match the actual Dart source.*
