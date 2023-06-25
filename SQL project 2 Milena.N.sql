-----project 2 - advanced SQL ---- 

---- Milena Nichenzon --- 

USE AdventureWorks2019

----1.  Products that were never purchased 
--      Columns: ProductID, Name (of product), Color, ListPrice, Size

SELECT 
    ProductID , Name AS 'Product name', Color , ListPrice , Size
FROM Production.Product 
WHERE not exists (SELECT ProductID 
                  FROM Sales.SalesOrderDetail 
			      WHERE Sales.SalesOrderDetail.ProductID = Production.Product.ProductID)
ORDER BY ProductID


----Updates to complete 

--update sales.customer set personid=customerid  
--       where customerid <=290  
--update sales.customer set personid=customerid+1700    
--       where customerid >= 300 and customerid<=350  
--update sales.customer set personid=customerid+1700    
--	   where customerid >= 352 and customerid<=701


----2. - Customers that have not placed any orders
--       Columns: CustomerID, FirstName, LastName in ascending order
--      *If there is missing data in columns FirstName and LastName - show value "Unknown"
SELECT 
    c.CustomerID
  , IIF(FirstName is null , 'unknow', FirstName ) AS 'FirstName'
  , IIF(LastName is null , 'unknow' , LastName ) AS 'LastName'
FROM Sales.Customer AS c 
     LEFT JOIN Person.Person AS p 
     ON c.PersonId = p.BusinessEntityID 
WHERE NOT EXISTS ( SELECT 1 
                   FROM Sales.SalesOrderHeader AS ord
                   WHERE ord.CustomerID = c.CustomerID ) 
ORDER BY c.CustomerID



----3. Top 10 customers that have placed the most orders
--	   Columns: CustomerID, FirstName, LastName and the amount of orders in descending order
SELECT Top 10 
      soh.CustomerID 
    , FirstName , LastName 
    , COUNT(SalesOrderID) AS CountOfOrders
FROM Sales.SalesOrderHeader AS soh
     JOIN Sales.Customer AS c
	 ON soh.CustomerID =c.CustomerID
	 JOIN Person.Person AS p 
	 ON p.BusinessEntityID = c.PersonID 
GROUP BY soh.CustomerID ,  FirstName , LastName 
ORDER BY CountOfOrders desc


----4. Data regarding employees and their job titles , amount of employees that share the same job title
--     Columns: FirstName, LastName, JobTitle, HireDate
SELECT 
    p.FirstName , p.LastName 
  , e.JobTitle , e.HireDate 
  , COUNT(e.BusinessEntityID) over(partition by e.JobTitle) AS 'CountOfTitle'
FROM HumanResources.Employee AS e 
     JOIN Person.Person AS p 
ON e.BusinessEntityID = p.BusinessEntityID



----5. Coustomers recent order date and the second most recent order date
--     Columns: SalesOrderID, CustomerID, LastName, FirstName, LastOrder, PreviousOrder
GO 

WITH OrderDates
AS
(  SELECT 
       SalesOrderID , CustomerID
     , OrderDate AS 'LastOrder' 
     , LAG(orderdate) over (partition by CustomerID order by salesorderid) AS 'PreviusOrder'
   FROM Sales.SalesOrderHeader 
)
SELECT 
    SalesOrderID , od.CustomerID
  , LastName , FirstName
  , LastOrder , PreviusOrder
FROM OrderDates od 
     JOIN Sales.Customer c 
	 ON od.CustomerID=c.CustomerID 
	 JOIN Person.Person p 
	 ON c.PersonID = p.BusinessEntityID
WHERE LastOrder in (SELECT MAX(LastOrder)
                    FROM OrderDates od
					WHERE od.CustomerID=c.CustomerID)
ORDER BY CustomerID


----6. The order with the highest total payment in each year , and which customer placed the order
--     Columns: Year, SalesOrderID, LastName, FirstName, Total
GO

WITH salesTotal
AS
(  SELECT
       YEAR(soh.OrderDate) AS 'year' , soh.SalesOrderID , soh.CustomerID 
     , SUM(UnitPrice*(1-UnitPriceDiscount)*OrderQty) AS 'total' 
     , DENSE_RANK() over(partition by YEAR(soh.OrderDate) order by SUM(UnitPrice*(1-UnitPriceDiscount)*OrderQty) desc) 'RNK'
  FROM Sales.SalesOrderDetail AS sod 
       JOIN Sales.SalesOrderHeader AS soh
       ON sod.SalesOrderID=soh.SalesOrderID
  GROUP BY  YEAR(soh.OrderDate) , soh.SalesOrderID , soh.CustomerID  
)
SELECT st.year , st.SalesOrderID , p.LastName , p.FirstName , total 
FROM salesTotal AS st 
     join Sales.Customer AS c 
     ON st.CustomerID = c.CustomerID 
     JOIN Person.Person AS p  
	 ON p.BusinessEntityID = c.PersonID 
WHERE RNK=1



----7. Number of orders for by month, for every year
--     Columns: Month and a column for every year
SELECT *
FROM (
       SELECT MONTH(orderdate) AS 'month' , YEAR(orderdate) AS 'year' , SalesOrderID
        FROM Sales.SalesOrderHeader ) a  
PIVOT ( COUNT(SalesOrderID) FOR year in ([2011] , [2012],[2013],[2014])) piv
ORDER BY month

----8.

SELECT YEAR(OrderDate) AS 'Year' 
     , CAST( MONTH(OrderDate) as char(2) ) AS 'Month'
     , SUM(SubTotal) AS 'SumPrice' 
     , SUM(SUM(SubTotal) ) over (partition by YEAR(OrderDate)  order by MONTH(OrderDate) ROWS   BETWEEN   UNBOUNDED   PRECEDING   AND   CURRENT   ROW) AS 'Money'
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate) , MONTH(OrderDate)

UNION 

SELECT YEAR(OrderDate) , 'Grand_Total' , null , SUM(SubTotal) over (partition by YEAR(OrderDate) )
FROM Sales.SalesOrderHeader

----9.Employees sorted by their hire date in every department from most to least recent, name and hire date for the last employee hired before them 
--             and the number of days between the two hire dates
--    Columns: DepartmentName, EmployeeID, EmployeeFullName, HireDate, Seniority, PreviousEmpName, PreviousEmpDate, DiffDays
SELECT * 
  , DATEDIFF (DD, PreviusEmpDate , HireDate) AS 'DiffDays'
FROM (  SELECT *
          , LAG(EmployeesFullName) over ( partition by DepartmentName order by HireDate  ) AS 'PreviusEmpName'
          , LAG(HireDate) over ( partition by DepartmentName order by HireDate ) AS 'PreviusEmpDate'
        FROM (  SELECT 
                    d.Name AS 'DepartmentName'
                  , e.BusinessEntityID AS 'EmployeesID' 
                  , CONCAT( p.FirstName ,' ', p.LastName ) AS 'EmployeesFullName'
                  , e.HireDate 
                  , DATEDIFF(MM, e.HireDate, GETDATE() ) AS 'Seniority'
                FROM HumanResources.Employee e 
                     JOIN HumanResources.EmployeeDepartmentHistory hde
	                 ON e.BusinessEntityID = hde.BusinessEntityID
	                 JOIN HumanResources.Department d
	                 ON hde.DepartmentID = d.DepartmentID
	                 JOIN Person.Person p
	                 ON e.BusinessEntityID = p.BusinessEntityID
				WHERE hde.EndDate IS NULL ) emp_seniority  ) PrevEmp
ORDER BY DepartmentName , HireDate desc


----10. Employees on the same department that were hired on the same day.
--		Columns : HireDate , DepartmentID ,Employees

SELECT 
   HireDate , DepartmentID  
 , STRING_AGG (CONCAT(e.BusinessEntityID,' ', LastName,' ', FirstName) , ' , ') WITHIN GROUP (ORDER BY hiredate)  AS 'employees'
FROM HumanResources.Employee e
     JOIN HumanResources.EmployeeDepartmentHistory d
	 ON e.BusinessEntityID = d.BusinessEntityID
	 JOIN Person.Person p 
	 ON p.BusinessEntityID = e.BusinessEntityID
WHERE d.EndDate IS NULL 
GROUP BY HireDate , DepartmentID
ORDER BY HireDate