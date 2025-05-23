
## 🇳🇬 **Ọ̀pẹ́ Kọ́sọfì – A Decentralized Digital Library System**

**Ọ̀pẹ́ Kọ́sọfì** means *"Gratitude for Knowledge Records"* in Yoruba, celebrating Nigeria’s literary spirit and technological future. This decentralized platform offers a robust and accountable way to manage digital libraries using Clarity smart contracts on the Stacks blockchain.

---

### 📚 Project Overview

**Ọ̀pẹ́ Kọ́sọfì** is a feature-rich smart contract-based library system that supports:

* Member registration and validation
* Book cataloging and borrowing
* Reading list tracking
* Reservation management
* Late fee handling
* Comprehensive statistics for library administrators

All interactions are verifiable and tamper-proof, leveraging the Clarity language for smart contracts.

---

### ✅ Features

* **Secure Member Registration**: Members register with a library card and receive a verifiable identity on-chain.
* **Book Borrowing**: Authorized members or librarians can assign books to users with due dates and enforce borrowing constraints.
* **Reading List Management**: Automatically track up to 25 borrowed books per member.
* **Late Fee Tracking & Payment**: Automatically calculates overdue penalties and allows payments.
* **Book Reservations**: Members can reserve currently unavailable books (limit: 10).
* **Library Statistics Dashboard**: Access aggregated data like total members, books, and reservations.
* **Card Management**: Members can update their library card when necessary.
* **Archived Transactions**: Safely remove transaction records from active lists when no longer needed.

---

### ⚙️ System Constraints

| Parameter             | Value         |
| --------------------- | ------------- |
| Max Title Length      | 1024 bytes    |
| Reading List Capacity | 25 books      |
| Max Borrow Duration   | 2160 seconds  |
| Reservation Limit     | 10 per member |

---

### 🔐 Error Codes

| Code | Meaning                    |
| ---- | -------------------------- |
| 200  | Access Denied              |
| 201  | Member Already Registered  |
| 202  | Member Not Found           |
| 203  | Book Not Available         |
| 204  | Reading List Full          |
| 205  | Book Already Borrowed      |
| 206  | Reservation Limit Exceeded |

---

### 🛠️ Key Smart Contract Maps & Variables

* **`library-members`** – Tracks member data
* **`library-books`** – Stores books metadata
* **`book-transactions`** – Records borrowing events
* **`member-reading-list`** – Active books per user
* **`book-reservations`** – Pending reservations
* **`total-books-borrowed`**, **`active-members`**, etc. – Track system statistics
