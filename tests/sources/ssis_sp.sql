CREATE PROCEDURE dbo.sp_LoadFactProjectMonthly
@SnapshotMonth INT -- format YYYYMM, e.g. 202410 = Oct 2024
AS
BEGIN
SET NOCOUNT ON;
-- Clear existing rows for the snapshot month
DELETE FROM dbo.FactProjectMonthly
WHERE SnapshotMonth = @SnapshotMonth;
-- Active or recently closed projects
SELECT
p.ProjectID,
p.ProjectCode,
p.ProjectName,
p.ClientID,
p.PMUserID,
p.OfficeID,
ISNULL(p.BudgetUSD, 0) AS BudgetUSD,
p.Status
INTO #ActiveProjects
FROM dbo.Projects p WITH (NOLOCK)
WHERE p.Status IN ('Active', 'OnHold')
OR (p.Status = 'Closed' AND p.ClosedDate >= DATEADD(MONTH, -3, GETDATE()));
-- Build month boundaries
DECLARE @MonthStart DATE =
DATEFROMPARTS(@SnapshotMonth / 100, @SnapshotMonth % 100, 1);
DECLARE @MonthEnd DATE = EOMONTH(@MonthStart);
-- Aggregate timesheets for the month
SELECT
ts.ProjectID,
ts.EmployeeID,
SUM(CASE WHEN ts.IsBillable = 1 THEN ts.Hours ELSE 0 END) AS BillableHours,
SUM(CASE WHEN ts.IsBillable = 0 THEN ts.Hours ELSE 0 END) AS NonBillableHours,
SUM(ts.Hours * ts.HourlyRate) AS RevenueUSD
INTO #MonthlyHours
FROM dbo.TimesheetEntries ts WITH (NOLOCK)
WHERE ts.EntryDate BETWEEN @MonthStart AND @MonthEnd
AND ts.IsApproved = 1
GROUP BY ts.ProjectID, ts.EmployeeID;
-- Current employee attributes
SELECT
e.EmployeeID,
e.EmployeeName,
e.Department,
e.Role,
e.TeamCode
INTO #EmployeeSnapshot
FROM dbo.Employees e WITH (NOLOCK)
WHERE e.IsActive = 1;
-- Build the fact
INSERT INTO dbo.FactProjectMonthly (
SnapshotMonth, ProjectID, EmployeeID, ClientID, OfficeID,
Department, Role, BillableHours, NonBillableHours, RevenueUSD, MonthlyBudgetUSD
)
SELECT
@SnapshotMonth,
ap.ProjectID,
mh.EmployeeID,
ap.ClientID,
ap.OfficeID,
es.Department,
es.Role,
mh.BillableHours,
mh.NonBillableHours,
mh.RevenueUSD,
ap.BudgetUSD / 12.0
FROM #ActiveProjects ap
INNER JOIN #MonthlyHours mh ON ap.ProjectID = mh.ProjectID
LEFT JOIN #EmployeeSnapshot es ON mh.EmployeeID = es.EmployeeID;
DROP TABLE #ActiveProjects;
DROP TABLE #MonthlyHours;
DROP TABLE #EmployeeSnapshot;
END