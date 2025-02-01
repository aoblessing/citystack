;; CityStack Smart Contract Architecture

;; Contract Owner
(define-data-var contract-owner (optional principal) none)

;; Initialize contract
(define-public (initialize (owner principal))
    (begin
        (asserts! (is-none (var-get contract-owner)) ERR-ALREADY-INITIALIZED)
        (var-set contract-owner (some owner))
        (ok true)
    )
)

;; Check contract owner
(define-private (is-contract-owner (caller principal))
    (let ((owner (unwrap! (var-get contract-owner) false)))
        (is-eq caller owner)
    )
)

;; Constants and Variables
(define-constant ERR-ALREADY-INITIALIZED (err u1000))
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-INVALID-PROPOSAL (err u1002))
(define-constant ERR-NO-PROPERTY (err u1003))
(define-constant ERR-ALREADY-REGISTERED (err u1004))
(define-constant ERR-INVALID-LOCATION (err u1005))
(define-constant ERR-ZONE-NOT-FOUND (err u1006))
(define-constant ERR-INSUFFICIENT-RESOURCES (err u1007))

(define-data-var proposal-counter uint u0)
(define-data-var min-voting-power uint u100)

;; Data Maps
(define-map zones 
    (string-utf8 10) 
    {
        name: (string-utf8 50),
        resource-limit: uint,
        used-resources: uint,
        development-type: (string-utf8 20)
    }
)

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

(define-map proposals 
    uint 
    {
        title: (string-utf8 100),
        description: (string-utf8 500),
        creator: principal,
        votes-for: uint,
        votes-against: uint,
        created-at: uint,
        status: (string-utf8 20),
        zone: (string-utf8 10),
        resources-required: uint
    }
)

(define-map votes
    {voter: principal, proposal-id: uint}
    {amount: uint, direction: bool}
)

;; Zone Management
(define-public (add-zone 
    (zone-id (string-utf8 10))
    (name (string-utf8 50))
    (resource-limit uint)
    (development-type (string-utf8 20)))
    (begin
        (asserts! (is-contract-owner tx-sender) ERR-NOT-AUTHORIZED)
        (ok (map-set zones zone-id {
            name: name,
            resource-limit: resource-limit,
            used-resources: u0,
            development-type: development-type
        }))
    )
)

(define-read-only (get-zone (zone-id (string-utf8 10)))
    (map-get? zones zone-id)
)

;; Property Registration
(define-public (register-property 
    (zone (string-utf8 10))
    (area uint))
    (let
        ((caller tx-sender))
        (asserts! (is-none (map-get? properties caller)) ERR-ALREADY-REGISTERED)
        (asserts! (is-some (map-get? zones zone)) ERR-ZONE-NOT-FOUND)
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

;; Proposal System
(define-public (create-proposal
    (title (string-utf8 100))
    (description (string-utf8 500))
    (zone (string-utf8 10))
    (resources uint))
    (let
        ((caller tx-sender)
         (proposal-id (+ (var-get proposal-counter) u1))
         (zone-data (unwrap! (map-get? zones zone) ERR-ZONE-NOT-FOUND)))
        
        (asserts! (is-some (map-get? properties caller)) ERR-NO-PROPERTY)
        (asserts! (<= (+ (get used-resources zone-data) resources) 
                     (get resource-limit zone-data)) 
                 ERR-INSUFFICIENT-RESOURCES)
        
        (map-set proposals 
            proposal-id
            {
                title: title,
                description: description,
                creator: caller,
                votes-for: u0,
                votes-against: u0,
                created-at: block-height,
                status: u"active",
                zone: zone,
                resources-required: resources
            }
        )
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

;; Voting System
(define-public (vote
    (proposal-id uint)
    (vote-for bool))
    (let
        ((caller tx-sender)
         (property (unwrap! (map-get? properties caller) ERR-NO-PROPERTY))
         (voting-power (get voting-power property))
         (current-proposal (unwrap! (map-get? proposals proposal-id) ERR-INVALID-PROPOSAL)))
        
        (asserts! (is-none (map-get? votes {voter: caller, proposal-id: proposal-id})) 
            ERR-NOT-AUTHORIZED)
        
        (map-set votes 
            {voter: caller, proposal-id: proposal-id}
            {amount: voting-power, direction: vote-for})
        
        (let
            ((updated-proposal (merge current-proposal 
                {
                    votes-for: (if vote-for 
                        (+ (get votes-for current-proposal) voting-power)
                        (get votes-for current-proposal)),
                    votes-against: (if vote-for
                        (get votes-against current-proposal)
                        (+ (get votes-against current-proposal) voting-power))
                })))
            (ok (map-set proposals proposal-id updated-proposal)))
    )
)

;; Read-Only Functions
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-property (owner principal))
    (map-get? properties owner)
)

(define-read-only (get-vote (voter principal) (proposal-id uint))
    (map-get? votes {voter: voter, proposal-id: proposal-id})
)

;; Private Functions
(define-private (calculate-voting-power (area uint))
    (+ (/ area u100) u1)
)
