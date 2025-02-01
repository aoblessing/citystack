;; CityStack Smart Contract Architecture - Step 1: Property and Voting

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and Variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var proposal-counter uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var min-voting-power uint u100)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Error Codes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-PROPOSAL (err u1001))
(define-constant ERR-NO-PROPERTY (err u1002))
(define-constant ERR-ALREADY-REGISTERED (err u1003))
(define-constant ERR-INVALID-LOCATION (err u1004))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Maps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Property Registry
(define-map properties 
    principal 
    {
        location: {
            zone: (string-utf8 10),
            area: uint
        },
        voting-power: uint,
        registration-time: uint
    }
)

;; Proposal Storage
(define-map proposals 
    uint 
    {
        title: (string-utf8 100),
        description: (string-utf8 500),
        creator: principal,
        votes-for: uint,
        votes-against: uint,
        created-at: uint,
        status: (string-utf8 20)
    }
)

;; Vote Tracking
(define-map votes
    {voter: principal, proposal-id: uint}
    {amount: uint, direction: bool}
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Property Registration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (register-property 
    (zone (string-utf8 10))
    (area uint))
    (let
        ((caller tx-sender))
        ;; Check if property not already registered
        (asserts! (is-none (map-get? properties caller)) ERR-ALREADY-REGISTERED)
        ;; Verify valid zone (you can add more validation)
        (asserts! (> (len zone) u0) ERR-INVALID-LOCATION)
        
        (ok (map-set properties 
            caller
            {
                location: {
                    zone: zone,
                    area: area
                },
                voting-power: (calculate-voting-power area),
                registration-time: block-height
            }))
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Proposal System
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (create-proposal
    (title (string-utf8 100))
    (description (string-utf8 500)))
    (let
        ((caller tx-sender)
         (proposal-id (+ (var-get proposal-counter) u1)))
        
        ;; Must have registered property to create proposal
        (asserts! (is-some (map-get? properties caller)) ERR-NO-PROPERTY)
        
        (map-set proposals 
            proposal-id
            {
                title: title,
                description: description,
                creator: caller,
                votes-for: u0,
                votes-against: u0,
                created-at: block-height,
                status: "active"
            }
        )
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote
    (proposal-id uint)
    (vote-for bool))
    (let
        ((caller tx-sender)
         (proposal (unwrap! (map-get? properties caller) ERR-NO-PROPERTY))
         (voting-power (get voting-power proposal))
         (current-proposal (unwrap! (map-get? proposals proposal-id) ERR-INVALID-PROPOSAL)))
        
        ;; Check if already voted
        (asserts! (is-none (map-get? votes {voter: caller, proposal-id: proposal-id})) 
            ERR-NOT-AUTHORIZED)
        
        ;; Record the vote
        (map-set votes 
            {voter: caller, proposal-id: proposal-id}
            {amount: voting-power, direction: vote-for})
        
        ;; Update proposal votes
        (ok (map-set proposals 
            proposal-id
            (merge current-proposal 
                (if vote-for
                    {votes-for: (+ (get votes-for current-proposal) voting-power)}
                    {votes-against: (+ (get votes-against current-proposal) voting-power)}))))
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-Only Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-property (owner principal))
    (map-get? properties owner)
)

(define-read-only (get-vote (voter principal) (proposal-id uint))
    (map-get? votes {voter: voter, proposal-id: proposal-id})
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Private Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (calculate-voting-power (area uint))
    ;; Simple voting power calculation based on area
    ;; Can be made more complex with zone multipliers later
    (+ (/ area u100) u1)
)
