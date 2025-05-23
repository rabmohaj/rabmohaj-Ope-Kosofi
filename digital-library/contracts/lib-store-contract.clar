;; DIGITAL-LIBRARY-SYSTEM - STAGE 3: COMPLETE IMPLEMENTATION
;; Full-featured library platform with advanced member management and comprehensive book services

;; Response codes
(define-constant ACCESS-DENIED u200)
(define-constant MEMBER-ALREADY-REGISTERED u201)
(define-constant MEMBER-NOT-FOUND u202)
(define-constant BOOK-NOT-AVAILABLE u203)
(define-constant READING-LIST-FULL u204)
(define-constant BOOK-ALREADY-BORROWED u205)
(define-constant RESERVATION-LIMIT-EXCEEDED u206)

;; System constraints
(define-constant BOOK-TITLE-LIMIT u1024)
(define-constant READING-LIST-CAPACITY u25)
(define-constant MAX-BORROW_DURATION u2160)
(define-constant MAX-RESERVATIONS u10)

;; Library statistics
(define-data-var total-books-borrowed uint u0)
(define-data-var active-members uint u0)
(define-data-var current-transaction-id uint u0)
(define-data-var total-books uint u0)
(define-data-var total-reservations uint u0)

;; Primary data structures
(define-map library-members principal 
  {
    is-active: bool,
    library-card: (buff 33),
    registration-date: uint,
    books-borrowed: uint,
    membership-tier: uint,
    late-fees: uint
  }
)

(define-map book-transactions uint 
  {
    borrower: principal,
    assigned-to: principal,
    book-info: (buff 1024),
    checkout-date: uint,
    due-date: uint,
    is-returned: bool,
    late-fee: uint
  }
)

(define-map library-books uint 
  {
    title: (buff 1024),
    author: (buff 512),
    isbn: (buff 64),
    added-by: principal,
    date-added: uint,
    is-available: bool,
    current-borrower: (optional principal),
    total-borrows: uint
  }
)

(define-map book-reservations uint 
  {
    book-id: uint,
    reserved-by: principal,
    reservation-date: uint,
    is-active: bool
  }
)

(define-map member-reading-list principal (list 25 uint))
(define-map member-reservations principal (list 10 uint))

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

(define-read-only (get-book-transaction (transaction-id uint))
  (map-get? book-transactions transaction-id)
)

(define-read-only (get-book-details (book-id uint))
  (map-get? library-books book-id)
)

(define-read-only (get-reservation-details (reservation-id uint))
  (map-get? book-reservations reservation-id)
)

(define-read-only (get-member-reading-list (member principal))
  (default-to (list) (map-get? member-reading-list member))
)

(define-read-only (get-member-reservations (member principal))
  (default-to (list) (map-get? member-reservations member))
)

(define-read-only (library-statistics)
  {
    total-transactions: (var-get total-books-borrowed),
    registered-members: (var-get active-members),
    total-books: (var-get total-books),
    active-reservations: (var-get total-reservations)
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
        books-borrowed: u0,
        membership-tier: u1,
        late-fees: u0
      }
    )
    
    ;; Initialize empty reading list and reservations
    (map-set member-reading-list applicant (list))
    (map-set member-reservations applicant (list))
    
    ;; Update membership counter
    (var-set active-members (+ (var-get active-members) u1))
    (ok true)
  )
)

;; Book addition to library
(define-public (add-book (title (buff 1024)) (author (buff 512)) (isbn (buff 64)))
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
        author: author,
        isbn: isbn,
        added-by: librarian,
        date-added: current-time,
        is-available: true,
        current-borrower: none,
        total-borrows: u0
      }
    )
    
    ;; Increment book counter
    (var-set total-books (+ book-id u1))
    
    (ok book-id)
  )
)

;; Book borrowing process
(define-public (borrow-book (recipient principal) (book-info (buff 1024)))
  (let (
    (librarian tx-sender)
    (transaction-id (var-get total-books-borrowed))
    (checkout-time (get-current-time))
    (due-time (+ checkout-time MAX-BORROW_DURATION))
    (librarian-profile (unwrap! (get-member-profile librarian) (err MEMBER-NOT-FOUND)))
    (recipient-reading-list (get-member-reading-list recipient))
  )
    ;; Verify librarian membership
    (asserts! (verify-membership librarian) 
              (err MEMBER-NOT-FOUND))
    
    ;; Verify recipient membership
    (asserts! (verify-membership recipient) 
              (err MEMBER-NOT-FOUND))
    
    ;; Check reading list capacity
    (asserts! (< (len recipient-reading-list) READING-LIST-CAPACITY)
              (err READING-LIST-FULL))
    
    ;; Create transaction record
    (map-set book-transactions transaction-id
      {
        borrower: librarian,
        assigned-to: recipient,
        book-info: book-info,
        checkout-date: checkout-time,
        due-date: due-time,
        is-returned: false,
        late-fee: u0
      }
    )
    
    ;; Update recipient's reading list
    (map-set member-reading-list 
             recipient
             (unwrap-panic (as-max-len? (append recipient-reading-list transaction-id) u25)))
    
    ;; Update librarian's transaction count
    (map-set library-members librarian
      (merge librarian-profile { 
        books-borrowed: (+ (get books-borrowed librarian-profile) u1)
      })
    )
    
    ;; Increment transaction counter
    (var-set total-books-borrowed (+ transaction-id u1))
    
    (ok transaction-id)
  )
)

;; Book return/reading confirmation
(define-public (mark-book-read (transaction-id uint))
  (let (
    (reader tx-sender)
    (transaction-details (unwrap! (get-book-transaction transaction-id) (err BOOK-NOT-AVAILABLE)))
    (current-time (get-current-time))
    (due-date (get due-date transaction-details))
    (late-fee (if (> current-time due-date) (- current-time due-date) u0))
  )
    ;; Verify reader is the assigned borrower
    (asserts! (is-eq (get assigned-to transaction-details) reader) 
              (err ACCESS-DENIED))
    
    ;; Mark as returned/read with potential late fee
    (map-set book-transactions transaction-id
      (merge transaction-details { 
        is-returned: true,
        late-fee: late-fee
      })
    )
    
    ;; Update member's late fees if applicable
    (if (> late-fee u0)
        (let ((member-profile (unwrap! (get-member-profile reader) (err MEMBER-NOT-FOUND))))
          (map-set library-members reader
            (merge member-profile { 
              late-fees: (+ (get late-fees member-profile) late-fee)
            }))
          true)
        true)
    
    (ok true)
  )
)

;; Book reservation system
(define-public (reserve-book (book-id uint))
  (let (
    (member tx-sender)
    (reservation-id (var-get total-reservations))
    (current-time (get-current-time))
    (member-reservations-list (get-member-reservations member))
    (book-details (unwrap! (get-book-details book-id) (err BOOK-NOT-AVAILABLE)))
  )
    ;; Verify member registration
    (asserts! (verify-membership member) 
              (err MEMBER-NOT-FOUND))
    
    ;; Check reservation limit
    (asserts! (< (len member-reservations-list) MAX-RESERVATIONS)
              (err RESERVATION-LIMIT-EXCEEDED))
    
    ;; Verify book is not available
    (asserts! (not (get is-available book-details))
              (err BOOK-ALREADY-BORROWED))
    
    ;; Create reservation
    (map-set book-reservations reservation-id
      {
        book-id: book-id,
        reserved-by: member,
        reservation-date: current-time,
        is-active: true
      }
    )
    
    ;; Update member's reservations
    (map-set member-reservations 
             member
             (unwrap-panic (as-max-len? (append member-reservations-list reservation-id) u10)))
    
    ;; Increment reservation counter
    (var-set total-reservations (+ reservation-id u1))
    
    (ok reservation-id)
  )
)

;; Transaction removal/archive
(define-public (archive-transaction (transaction-id uint))
  (let (
    (requester tx-sender)
    (transaction-details (unwrap! (get-book-transaction transaction-id) (err BOOK-NOT-AVAILABLE)))
  )
    ;; Verify requester has permission (librarian or borrower)
    (asserts! (or 
               (is-eq (get borrower transaction-details) requester)
               (is-eq (get assigned-to transaction-details) requester))
             (err ACCESS-DENIED))
    
    ;; Remove from reading list if requester is the borrower
    (if (is-eq (get assigned-to transaction-details) requester)
        (begin
          (var-set current-transaction-id transaction-id)
          (map-set member-reading-list 
                   requester 
                   (fold remove-from-reading-list (get-member-reading-list requester) (list))))
        true)
    
    ;; Archive the transaction
    (map-delete book-transactions transaction-id)
    
    (ok true)
  )
)

;; Reading list maintenance helper
(define-private (remove-from-reading-list (transaction-id uint) (updated-list (list 25 uint)))
  (if (is-eq transaction-id (var-get current-transaction-id))
      updated-list
      (unwrap-panic (as-max-len? (append updated-list transaction-id) u25)))
)

;; Pay late fees
(define-public (pay-late-fees (amount uint))
  (let (
    (member tx-sender)
    (member-profile (unwrap! (get-member-profile member) (err MEMBER-NOT-FOUND)))
    (current-fees (get late-fees member-profile))
  )
    ;; Verify payment amount doesn't exceed owed fees
    (asserts! (<= amount current-fees) (err ACCESS-DENIED))
    
    ;; Update member's fee balance
    (map-set library-members member
      (merge member-profile { 
        late-fees: (- current-fees amount)
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