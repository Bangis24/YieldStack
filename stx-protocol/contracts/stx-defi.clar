;; DeFi Yield Farming Protocol 

;; Constants
(define-constant ERR-NOT-PROTOCOL-ADMIN (err u1))
(define-constant ERR-POOL-NOT-ACTIVE (err u2))
(define-constant ERR-INVALID-VAULT (err u3))
(define-constant ERR-ALREADY-HARVESTED (err u4))
(define-constant ERR-WRONG-PROOF-OF-STAKE (err u5))
(define-constant ERR-LOCK-PERIOD-ACTIVE (err u6))
(define-constant ERR-INVALID-PARAMETER (err u8))
(define-constant MAX-VAULT-ID u100) ;; Maximum allowed vault ID

;; Data Variables
(define-data-var protocol-admin principal tx-sender)
(define-data-var pool-active bool false)
(define-data-var current-epoch uint u0)
(define-data-var entry-deposit uint u1000000) ;; 1 STX
(define-data-var total-liquidity uint u0)
(define-data-var current-block uint u0) ;; Block tracking for lock periods

;; Vault Structure
(define-map yield-vaults
    uint
    {
        strategy: (string-utf8 256),
        verification-hash: (buff 32), ;; SHA256 hash of the expected proof of stake
        unlock-block: uint,           ;; Unlock block for the vault
        yield-amount: uint,
        harvested: bool
    }
)

;; Farmer Progress Tracking
(define-map farmer-positions
    principal
    {
        current-vault: uint,
        harvested-vaults: (list 10 uint),
        total-harvested: uint
    }
)

;; Harvest History
(define-map vault-harvests
    {vault: uint, farmer: principal}
    {
        harvested-at: (optional uint)
    }
)

;; Authorization
(define-private (is-admin)
    (is-eq tx-sender (var-get protocol-admin)))

;; Block Management
(define-public (update-block (new-block uint))
    (begin
        (asserts! (is-admin) ERR-NOT-PROTOCOL-ADMIN)
        ;; Validate block is not less than current
        (asserts! (>= new-block (var-get current-block)) ERR-INVALID-PARAMETER)
        (var-set current-block new-block)
        (ok true)))

;; Protocol Management Functions
(define-public (launch-pool)
    (begin
        (asserts! (is-admin) ERR-NOT-PROTOCOL-ADMIN)
        (var-set pool-active true)
        (var-set current-epoch u0)
        (var-set total-liquidity u0)
        (ok true)))

(define-public (create-vault
    (vault-id uint)
    (strategy (string-utf8 256))
    (verification-hash (buff 32))
    (unlock-block uint)
    (yield-amount uint))
    (begin
        (asserts! (is-admin) ERR-NOT-PROTOCOL-ADMIN)
        
        ;; Validate vault-id is within acceptable range
        (asserts! (<= vault-id MAX-VAULT-ID) ERR-INVALID-PARAMETER)
        
        ;; Validate unlock block is in the future
        (asserts! (>= unlock-block (var-get current-block)) ERR-INVALID-PARAMETER)
        
        ;; Set the vault data
        (map-set yield-vaults vault-id
            {
                strategy: strategy,
                verification-hash: verification-hash,
                unlock-block: unlock-block,
                yield-amount: yield-amount,
                harvested: false
            })
            
        ;; Update the total liquidity
        (var-set total-liquidity (+ (var-get total-liquidity) yield-amount))
        (ok true)))

;; Farmer Onboarding
(define-public (deposit-liquidity)
    (begin
        (asserts! (var-get pool-active) ERR-POOL-NOT-ACTIVE)
        ;; Require entry deposit
        (try! (stx-transfer? (var-get entry-deposit) tx-sender (var-get protocol-admin)))
        
        (map-set farmer-positions tx-sender
            {
                current-vault: u0,
                harvested-vaults: (list),
                total-harvested: u0
            })
        (ok true)))

;; Harvest Functions
(define-public (harvest-yield
    (vault-id uint)
    (proof-of-stake (buff 32)))
    (let (
        (vault (unwrap! (map-get? yield-vaults vault-id) ERR-INVALID-VAULT))
        (farmer (unwrap! (map-get? farmer-positions tx-sender) ERR-INVALID-VAULT))
        (current-height (var-get current-block))
        )
        ;; Check vault availability
        (asserts! (var-get pool-active) ERR-POOL-NOT-ACTIVE)
        (asserts! (>= current-height (get unlock-block vault)) ERR-LOCK-PERIOD-ACTIVE)
        (asserts! (not (get harvested vault)) ERR-ALREADY-HARVESTED)
        
        ;; Verify proof of stake - directly compare the hashes
        (if (is-eq proof-of-stake (get verification-hash vault))
            (begin
                ;; Update vault status
                (map-set yield-vaults vault-id
                    (merge vault {harvested: true}))
                
                ;; Update farmer position
                (map-set farmer-positions tx-sender
                    (merge farmer {
                        current-vault: (+ vault-id u1),
                        harvested-vaults: (unwrap! (as-max-len? 
                            (append (get harvested-vaults farmer) vault-id) u10)
                            ERR-INVALID-VAULT),
                        total-harvested: (+ (get total-harvested farmer) u1)
                    }))
                
                ;; Record harvest
                (map-set vault-harvests
                    {vault: vault-id, farmer: tx-sender}
                    {
                        harvested-at: (some current-height)
                    })
                
                ;; Distribute yield
                (try! (stx-transfer? (get yield-amount vault) (var-get protocol-admin) tx-sender))
                
                (ok true))
            ERR-WRONG-PROOF-OF-STAKE)))

;; Read-only functions
(define-read-only (get-vault-strategy (vault-id uint))
    (match (map-get? yield-vaults vault-id)
        vault (if (>= (var-get current-block) (get unlock-block vault))
            (ok (get strategy vault))
            ERR-LOCK-PERIOD-ACTIVE)
        ERR-INVALID-VAULT))

(define-read-only (get-farmer-status (farmer principal))
    (map-get? farmer-positions farmer))

(define-read-only (get-vault-harvest (vault-id uint) (farmer principal))
    (map-get? vault-harvests {vault: vault-id, farmer: farmer}))

(define-read-only (get-current-block)
    (var-get current-block))

(define-read-only (get-pool-stats)
    {
        active: (var-get pool-active),
        current-epoch: (var-get current-epoch),
        total-liquidity: (var-get total-liquidity),
        entry-deposit: (var-get entry-deposit),
        current-block: (var-get current-block)
    })