;; DeFi Yield Farming Protocol 

;; Constants
(define-constant ERR-NOT-PROTOCOL-ADMIN (err u1))
(define-constant ERR-POOL-NOT-ACTIVE (err u2))
(define-constant ERR-INVALID-VAULT (err u3))
(define-constant ERR-ALREADY-HARVESTED (err u4))

;; Data Variables
(define-data-var protocol-admin principal tx-sender)
(define-data-var pool-active bool false)
(define-data-var current-epoch uint u0)
(define-data-var entry-deposit uint u1000000) ;; 1 STX
(define-data-var total-liquidity uint u0)

;; Vault Structure
(define-map yield-vaults
    uint
    {
        strategy: (string-utf8 256),
        yield-amount: uint,
        harvested: bool
    }
)

;; Farmer Progress Tracking
(define-map farmer-positions
    principal
    {
        current-vault: uint,
        total-harvested: uint
    }
)

;; Authorization
(define-private (is-admin)
    (is-eq tx-sender (var-get protocol-admin)))

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
    (yield-amount uint))
    (begin
        (asserts! (is-admin) ERR-NOT-PROTOCOL-ADMIN)
        
        ;; Set the vault data
        (map-set yield-vaults vault-id
            {
                strategy: strategy,
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
                total-harvested: u0
            })
        (ok true)))

;; Harvest Functions
(define-public (harvest-yield (vault-id uint))
    (let (
        (vault (unwrap! (map-get? yield-vaults vault-id) ERR-INVALID-VAULT))
        (farmer (unwrap! (map-get? farmer-positions tx-sender) ERR-INVALID-VAULT))
        )
        ;; Check vault availability
        (asserts! (var-get pool-active) ERR-POOL-NOT-ACTIVE)
        (asserts! (not (get harvested vault)) ERR-ALREADY-HARVESTED)
        
        ;; Update vault status
        (map-set yield-vaults vault-id
            (merge vault {harvested: true}))
        
        ;; Update farmer position
        (map-set farmer-positions tx-sender
            (merge farmer {
                current-vault: (+ vault-id u1),
                total-harvested: (+ (get total-harvested farmer) u1)
            }))
        
        ;; Distribute yield
        (try! (stx-transfer? (get yield-amount vault) (var-get protocol-admin) tx-sender))
        
        (ok true)))

;; Read-only functions
(define-read-only (get-vault-strategy (vault-id uint))
    (match (map-get? yield-vaults vault-id)
        vault (ok (get strategy vault))
        ERR-INVALID-VAULT))

(define-read-only (get-farmer-status (farmer principal))
    (map-get? farmer-positions farmer))

(define-read-only (get-pool-stats)
    {
        active: (var-get pool-active),
        current-epoch: (var-get current-epoch),
        total-liquidity: (var-get total-liquidity),
        entry-deposit: (var-get entry-deposit)
    })