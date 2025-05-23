;; DIGITAL-LIBRARY-SYSTEM - STAGE 2: BORROWING SYSTEM IMPLEMENTATION
;; Enhanced library with book borrowing and basic transaction tracking

;; Response codes
(define-constant ACCESS-DENIED u200)
(define-constant MEMBER-ALREADY-REGISTERED u201)
(define-constant MEMBER-NOT-FOUND u202)
(define-constant BOOK-NOT-AVAILABLE u203)
(define-constant BOOK-ALREADY-BORROWED u205)

;; System constraints
(define-constant BOOK-TITLE-LIMIT u512)
(define-constant MAX-BORROW_DURATION u2160) ;; 15 days in blocks

;; Library statistics
(define-data-var total-members uint u0)
(define-data-var total-books uint u0)
(define-data-var total-transactions uint u0)

;; Primary data structures
(define-map library-members principal 
  {
    is-active: bool,
    library-card: (buff 33),
    registration-date: uint,
    books-borrowed: uint
  }
)

(define-map library-books uint 
  {
    title: (buff 512),
    added-by: principal,
    date-added: uint,
    is-available: bool,
    current-borrower: (optional principal)
  }
)

(define-map borrow-transactions uint 
  {
    book-id: uint,
    borrower: principal,
    checkout-date: uint,
    due-date: uint,
    is-returned: bool
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

(define-read-only (get-transaction-details (transaction-id uint))
  (map-get? borrow-transactions transaction-id)
)

(define-read-only (library-statistics)
  {
    total-members: (var-get total-members),
    total-books: (var-get total-books),
    total-transactions: (var-get total-transactions)
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
        registration-date: registration-time,
        books-borrowed: u0
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
        is-available: true,
        current-borrower: none
      }
    )
    
    ;; Increment book counter
    (var-set total-books (+ book-id u1))
    
    (ok book-id)
  )
)

;; Book borrowing process
(define-public (borrow-book (book-id uint))
  (let (
    (borrower tx-sender)
    (transaction-id (var-get total-transactions))
    (checkout-time (get-current-time))
    (due-time (+ checkout-time MAX-BORROW_DURATION))
    (book-details (unwrap! (get-book-details book-id) (err BOOK-NOT-AVAILABLE)))
    (borrower-profile (unwrap! (get-member-profile borrower) (err MEMBER-NOT-FOUND)))
  )
    ;; Verify borrower membership
    (asserts! (verify-membership borrower) 
              (err MEMBER-NOT-FOUND))
    
    ;; Check book availability
    (asserts! (get is-available book-details)
              (err BOOK-ALREADY-BORROWED))
    
    ;; Create transaction record
    (map-set borrow-transactions transaction-id
      {
        book-id: book-id,
        borrower: borrower,
        checkout-date: checkout-time,
        due-date: due-time,
        is-returned: false
      }
    )
    
    ;; Update book status
    (map-set library-books book-id
      (merge book-details { 
        is-available: false,
        current-borrower: (some borrower)
      })
    )
    
    ;; Update borrower's book count
    (map-set library-members borrower
      (merge borrower-profile { 
        books-borrowed: (+ (get books-borrowed borrower-profile) u1)
      })
    )
    
    ;; Increment transaction counter
    (var-set total-transactions (+ transaction-id u1))
    
    (ok transaction-id)
  )
)

;; Book return process
(define-public (return-book (transaction-id uint))
  (let (
    (returner tx-sender)
    (transaction-details (unwrap! (get-transaction-details transaction-id) (err BOOK-NOT-AVAILABLE)))
    (book-id (get book-id transaction-details))
    (book-details (unwrap! (get-book-details book-id) (err BOOK-NOT-AVAILABLE)))
  )
    ;; Verify returner is the borrower
    (asserts! (is-eq (get borrower transaction-details) returner) 
              (err ACCESS-DENIED))
    
    ;; Verify book hasn't been returned already
    (asserts! (not (get is-returned transaction-details))
              (err BOOK-ALREADY-BORROWED))
    
    ;; Mark transaction as returned
    (map-set borrow-transactions transaction-id
      (merge transaction-details { is-returned: true })
    )
    
    ;; Update book availability
    (map-set library-books book-id
      (merge book-details { 
        is-available: true,
        current-borrower: none
      })
    )
    
    (ok true)
  )
)

;; Library card update
(define-public (update-library-card (new-card (buff 33)))
  (let (
    (member tx-sender)
    (member-profile (unwrap! (get-member-profile member) (err MEMBER-NOT-FOUND)))
  )
    ;; Update the library card
    (map-set library-members member
      (merge member-profile { library-card: new-card })
    )
    
    (ok true)
  )
)