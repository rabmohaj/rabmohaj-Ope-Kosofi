;; DIGITAL-LIBRARY-SYSTEM - STAGE 1: MVP IMPLEMENTATION
;; Basic library membership and book registration functionality

;; Response codes
(define-constant MEMBER-ALREADY-REGISTERED u201)
(define-constant MEMBER-NOT-FOUND u202)

;; System constraints
(define-constant BOOK-TITLE-LIMIT u512)

;; Library statistics
(define-data-var total-members uint u0)
(define-data-var total-books uint u0)

;; Primary data structures
(define-map library-members principal 
  {
    is-active: bool,
    library-card: (buff 33),
    registration-date: uint
  }
)

(define-map library-books uint 
  {
    title: (buff 512),
    added-by: principal,
    date-added: uint,
    is-available: bool
  }
)

;; Timestamp utility
(define-private (get-current-time)
  (default-to u0 (get-block-info? time u0))
)

;; Information retrieval functions
(define-read-only (get-member-profile (member principal))
  (map-get? library-members member)
)

(define-read-only (verify-membership (member principal))
  (is-some (map-get? library-members member))
)

(define-read-only (get-book-details (book-id uint))
  (map-get? library-books book-id)
)

(define-read-only (library-statistics)
  {
    total-members: (var-get total-members),
    total-books: (var-get total-books)
  }
)

;; Member registration process
(define-public (register-membership (library-card (buff 33)))
  (let (
    (applicant tx-sender)
    (registration-time (get-current-time))
  )
    ;; Prevent duplicate registrations
    (asserts! (not (verify-membership applicant)) 
              (err MEMBER-ALREADY-REGISTERED))
    
    ;; Establish member profile
    (map-set library-members applicant
      {
        is-active: true,
        library-card: library-card,
        registration-date: registration-time
      }
    )
    
    ;; Update membership counter
    (var-set total-members (+ (var-get total-members) u1))
    (ok true)
  )
)

;; Book addition to library
(define-public (add-book (title (buff 512)))
  (let (
    (librarian tx-sender)
    (book-id (var-get total-books))
    (current-time (get-current-time))
  )
    ;; Verify librarian membership
    (asserts! (verify-membership librarian) 
              (err MEMBER-NOT-FOUND))
    
    ;; Add book to library
    (map-set library-books book-id
      {
        title: title,
        added-by: librarian,
        date-added: current-time,
        is-available: true
      }
    )
    
    ;; Increment book counter
    (var-set total-books (+ book-id u1))
    
    (ok book-id)
  )
)