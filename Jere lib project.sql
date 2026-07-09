-- Task 1. Create a New Book Record -- "978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.')"

insert into books(isbn, book_title, category, rental_price, status, author, publisher)
values
('978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.');


-- Task 2: Update an Existing Member's Address

update members
set member_address = '125 Main St'
where member_id = 'C101';

-- Task 3: Delete a Record from the Issued Status Table 
-- Objective: Delete the record with issued_id = 'IS121' from the issued_status table.

select * from issued_status
where issued_id = 'IS121';

delete from issued_status
where issued_id = 'IS121'

-- Task 4: Retrieve All Books Issued by a Specific Employee -- Objective: Select all books issued by the employee with emp_id = 'E101'.

select * from issued_status
where issued_emp_id = 'E101';


--Task 5: List Members Who Have Issued More Than One Book -- Objective: Use GROUP BY to find members who have issued more than one book.

select ist.issued_emp_id, e.emp_name  from issued_status as ist 
join employees as e
on ist.issued_emp_id = e.emp_id
group by 1,2 
having count(ist.issued_id)>1;

--Task 6: Create Summary Tables: Used CTAS to generate new tables based on query results - each book and total book_issued_cnt**

create table book_cnts 
as 
select b.isbn, b.book_title, count(ist.issued_id) as no_issued from books as b 
join issued_status as ist 
on ist.issued_book_isbn = b.isbn
group by 1,2;

-- Task 7. Retrieve All Books in a Specific Category:

select * from books
where category = 'Classic';

-- Task 8: Find Total Rental Income by Category:

select b.category, sum(b.rental_price), count(*) from books as b 
join issued_status as ist 
on ist.issued_book_isbn = b.isbn
group by 1;

-- Task 9: List Members Who Registered in the Last 180 Days:

select * from members
where reg_date >= current_date - interval '180 days';

-- Task 10 List Employees with Their Branch Manager's Name and their branch details:

select e.*, em.emp_name as manager, b.branch_address from employees as e 
join branch as b
on b.branch_id = e.branch_id 
join employees as em
on em.emp_id = b.manager_id;

-- Task 11. Create a Table of Books with Rental Price Above a Certain Threshold 7USD:

create table books_price_greater_than_seven 
as
select * from books 
where rental_price > 7;

-- Task 12: Retrieve the List of Books Not Yet Returned

select * from issued_status as ist 
left join return_status as rst 
on ist.issued_id = rst.issued_id 
where rst.return_id is null;

/*
Task 13: 
Identify Members with Overdue Books
Write a query to identify members who have overdue books (assume a 30-day return period). 
Display the member's_id, member's name, book title, issue date, and days overdue.
*/

select ist.issued_member_id, m.member_name, ist.issued_book_name, ist.issued_date, current_date - ist.issued_date as overdue_days
from issued_status as ist 
join members as m
on m.member_id = ist.issued_member_id 
join books as b
on b.isbn = ist.issued_book_isbn 
left join return_status as rst 
on rst.issued_id = ist.issued_id 
where rst.return_date is null and (current_date - ist.issued_date)>30;


/*    
Task 14: Update Book Status on Return
Write a query to update the status of books in the books table to "Yes" when they are returned (based on entries in the return_status table).
*/

create or replace procedure add_return_records (p_return_id varchar, p_issued_id varchar, p_book_quality varchar )
language plpgsql 
as $$

declare 
     v_book_name varchar;
	 v_isbn varchar;
begin 
     insert into return_status (return_id, issued_id, return_date, book_quality) 
	 values (p_return_id, p_issued_id, current_date, p_book_quality);

     select 
	 issued_book_name,
	 issued_book_isbn 
	 into 
	 v_book_name,
	 v_isbn 
	 from issued_status 
	 where issued_id = p_issued_id;
	     
	 update books
	 set status = 'yes'
	 where isbn = v_isbn;

	 raise notice 'Thank you for returning the book: %', v_book_name;
end;
$$

/*
Task 15: Branch Performance Report
Create a query that generates a performance report for each branch, showing the number of books issued, the number of books returned, and the total revenue generated from book rentals.
*/

create table branch_reports as 
select 
     b.branch_id,
	 b.manager_id,
	 sum(bk.rental_price) as total_revenue, 
	 count(ist.issued_id) as num_of_book_issued,
	 count(rst.return_id) as num_of_books_returned
from issued_status as ist 
join employees as e 
on e.emp_id = ist.issued_emp_id 
join branch as b 
on b.branch_id = e.branch_id 
left join return_status as rst 
on rst.issued_id = ist.issued_id 
join books as bk 
on bk.isbn = ist.issued_book_isbn
group by 1,2;


-- Task 16: CTAS: Create a Table of Active Members
-- Use the CREATE TABLE AS (CTAS) statement to create a new table active_members containing members who have issued at least one book in the last 2 months.

create table active_members as 
select * from members
where member_id in(
       select distinct(issued_member_id) from issued_status 
       where issued_date >= current_date - interval '2 months')

-- Task 17: Find Employees with the Most Book Issues Processed
-- Write a query to find the top 3 employees who have processed the most book issues. Display the employee name, number of books processed, and their branch.

select 
    e.emp_name, b.*,
    count(ist.issued_id) as no_book_issued
from issued_status as ist
join
employees as e
on e.emp_id = ist.issued_emp_id
join
branch as b
on e.branch_id = b.branch_id
group by 1, 2
order by 3 desc
limit 3;

/*
Task 18: Stored Procedure Objective: 

Create a stored procedure to manage the status of books in a library system. 

Description: Write a stored procedure that updates the status of a book in the library based on its issuance. 

The procedure should function as follows: 

The stored procedure should take the book_id as an input parameter. 

The procedure should first check if the book is available (status = 'yes'). 

If the book is available, it should be issued, and the status in the books table should be updated to 'no'. 

If the book is not available (status = 'no'), the procedure should return an error message indicating that the book is currently not available.
*/

create or replace procedure issue_book (p_issued_id varchar, p_issued_member_id varchar, p_issued_book_isbn varchar, p_issued_emp_id varchar)
language plpgsql 
as $$ 

declare 
    v_status varchar;
	v_book_title varchar;
begin 
    select 
	status, 
	book_title 
    into 
	v_status,
	v_book_title
	from books
	where isbn = p_issued_book_isbn;

	if v_status = 'yes' then 
	    insert into issued_status(issued_id, issued_member_id, issued_date, issued_book_isbn, issued_emp_id)
	    values (p_issued_id, p_issued_member_id, current_date, p_issued_book_isbn, p_issued_emp_id);

		update books
		set status = 'no'
		where isbn = p_issued_book_isbn;

		raise notice 'Book records added successfully for book isbn: %', p_issued_book_isbn;

	else 
	    raise notice 'Sorry to inform you that the book is unavailable: %', v_book_title;
	end if;

end;
$$



