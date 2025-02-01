;; CityStack Smart Contract Architecture - Minimal Version

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and Variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var proposal-counter uint u0)
(define-data-var contract-owner principal tx-sender)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Error Codes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-PROPOSAL (err u1001))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Maps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Simple Proposal Storage
(define-map proposals 
    uint 
    {
        title: (string-utf8 100),
        description: (string-utf8 500),
        creator: principal,
        votes-for: uint,
        votes-against: uint
    }
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Create Proposal
(define-public (create-proposal
    (title (string-utf8 100))
    (description (string-utf8 500)))
    (let
        ((proposal-id (+ (var-get proposal-counter) u1)))
        (map-set proposals 
            proposal-id
            {
                title: title,
                description: description,
                creator: tx-sender,
                votes-for: u0,
                votes-against: u0
            }
        )
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

;; Vote on Proposal
(define-public (vote
    (proposal-id uint)
    (vote-for bool))
    (let
        ((proposal (unwrap! (map-get? proposals proposal-id) ERR-INVALID-PROPOSAL)))
        (if vote-for
            (map-set proposals proposal-id 
                (merge proposal {
                    votes-for: (+ (get votes-for proposal) u1)
                }))
            (map-set proposals proposal-id 
                (merge proposal {
                    votes-against: (+ (get votes-against proposal) u1)
                }))
        )
        (ok true)
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-Only Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)
