
### Key feature comparison to previous Ad Hoc examples (default values used)

| Feature                | Foundation | Soapbox Platform | ACO API | QPP Foundational | USCIS RFDS RFI |
|------------------------|------------|------------------|---------|------------------|----------------|
| Public Subnet          | X          | X                | X       | X                | X              |
| Egress-only App Subnet | X          | X                | *       | -                | X              |
| Private App Subnet     | -          | -                | *       | X                | -              |
| Private Data Subnet    | X          | -                | X       | X                | X              |
| VPC Size               | /16        | /16              | /21     | /16              | /16            |
| Number of AZs          | 3          | 2                | 2       | 2                | 2              |
| Private DNS            | X          | -                | -       | X                | -              |

Key:
 - X = Present
 - - = Absent
 - * = Optional

