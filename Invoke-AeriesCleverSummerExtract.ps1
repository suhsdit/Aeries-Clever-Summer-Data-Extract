#Requires -Modules AeriesApi, Microsoft.PowerShell.SecretManagement

# Load Config
. .\config.ps1

# ouput basic information from config
Write-Host "Export Path: $ExportPath"
Write-Host "Aeries URL: $AeriesUrl"
Write-Host "Database Year: $DbYear"

# Create Export Directory
$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$ExportDirectory = Join-Path -Path $ExportPath -ChildPath $Timestamp
if (-not (Test-Path -Path $ExportDirectory)) {
    New-Item -ItemType Directory -Path $ExportDirectory
}

# Start Logging using Transcript
$LogPath = Join-Path -Path $ExportDirectory -ChildPath "log-$Timestamp.txt"
start-transcript -Path $LogPath -Append

# Create Hash Table for Clever Teachers
$CleverTeacherHT = @{}
$CleverTeachers | ForEach-Object {$CleverTeacherHT.Add($_.teacher_sis_id, $_)}
Write-Host "Existing Clever Teachers: $($CleverTeacherHT.Count)"

# Create Hash Table for Clever Students
$CleverStudentHT = @{}
$CleverStudents | ForEach-Object {$CleverStudentHT.Add($_.student_sis_id, $_)}
Write-Host "Existing Clever Students: $($CleverStudentHT.Count)"

# Initialize Aeries API
Initialize-AeriesApi -URL $AeriesUrl -Certificate ($AeriesApiKey | ConvertFrom-SecureString -AsPlainText) -DatabaseYear $DbYear

# Create HT for Courses by course ID
$Courses = Get-AeriesCourseInformation

$CourseHT = @{}
$Courses | ForEach-Object {$CourseHT.Add($_.ID, $_)}

$NewStudents = @()
$NewTeachers = @()
$Sections = @()
$Enrollments = @()

foreach ($Config in $Configs) {


    # List all config values
    Write-Host "Summer School Name: $($Config.SummerSchoolName)"
    Write-Host "Term Name: $($Config.TermName)"
    Write-Host "Term Start: $($Config.TermStart)"
    Write-Host "Term End: $($Config.TermEnd)"
    

    # Get Summer School Data from Aeries
    $SummerSchool = Get-AeriesSchool | Where-Object {$_.Name -like $Config.SummerSchoolName}
    $SummerStudents = Get-AeriesStudent -SchoolCode $SummerSchool.SchoolCode
    $SummerTeachers = Get-AeriesTeacher -SchoolCode $SummerSchool.SchoolCode
    $SummerSections = Get-AeriesSection -SchoolCode $SummerSchool.SchoolCode
    $SummerRosters = $SummerSections | ForEach-Object {Get-AeriesSectionRoster -SchoolCode $SummerSchool.SchoolCode -SectionNumber $_.SectionNumber}
    Write-Host "Summer School Students: $($SummerStudents.Count)"
    Write-Host "Summer School Teachers: $($SummerTeachers.Count)"
    Write-Host "Summer School Sections: $($SummerSections.Count)"
    Write-Host "Summer School Rosters: $($SummerRosters.Count)"

    # Format student data for Clever
    $students = $SummerStudents | ForEach-Object {
        [pscustomobject]@{
            School_id = $_.SchoolCode #Required
            Student_id = $_.StudentID #Required
            Student_number = $_.StudentID # There is also a StudentNumber property, but this is the default Aeries/Clever mapping
            State_id = $_.StateStudentID
            Last_name = $_.LastName #Required
            Middle_name = $_.MiddleName
            First_name = $_.FirstName #Required
            Grade = $_.Grade
            Gender = $_.Gender
            #Graduation_year = $_.
            DOB = $_.BirthDate
            #Race = $_
            #Hispanic_Latino = $_
            Home_language = $_.HomeLanguageCode
            #Ell_status = $_
            #Frl_status = $_
            #IEP_status = $_
            Student_Street = $_.MailingAddress
            Student_City = $_.MailingAddressCity
            Student_State = $_.MailingAddressState
            Student_zip = $_.MailingAddressZipCode
            Student_email = $_.StudentEmailAddress
            #Contact_relationship = $_
            #Contact_type = $_
            #Contact_name = $_
            #Contact_phone = $_
            #Contact_phone_type = $_
            #Contact_email = $_
            #Contact_sis_id = $_
            Username = $_.StudentEmailAddress
            Password = $_.NetworkLoginID
            #Unweighted_gpa = $_
            #Weighted_gpa = $_
            #ext.* Additional data sent over in extension field.
        }
    }

    # Check if student is already in Clever, if not add to $NewStudents
    foreach ($student in $students) {
        if (-not $CleverStudentHT.ContainsKey($student.Student_id.ToString())) {
            $NewStudents += $student
        }
    }
    Write-Host "New Students: $($NewStudents.Count)"

    # Format teacher data for Clever
    $teachers = $SummerTeachers | ForEach-Object {
        [pscustomobject]@{
            School_id = $_.SchoolCode #Required
            Teacher_id = $_.StaffID1 #Required
            Teacher_number = $_.StaffID1
            #State_teacher_id = $_.
            Teacher_email = $_.EmailAddress
            First_name = $_.FirstName #Required
            Last_name = $_.LastName #Required
            #Title = $_
            #Username = $_
            #Password = $_
            #ext.* Additional data sent over in extension field.
        }
    }
    # Check if teacher is already in Clever, if not add to $NewTeachers
    foreach ($teacher in $teachers) {
        if (-not $CleverTeacherHT.ContainsKey($teacher.Teacher_id.ToString())) {
            $NewTeachers += $teacher
        }
    }
    Write-Host "New Teachers: $($NewTeachers.Count)"
    

    # Format section data for Clever
    $Sections += $SummerSections | ForEach-Object {
        [pscustomobject]@{
            School_id = $_.SchoolCode #Required
            Section_id = "$($config.SectionPrefix)$($_.SectionNumber)" #Required
            Teacher_id = $_.SectionStaffMembers[0].StaffID #Required
            Teacher_2_id = $_.SectionStaffMembers[1].StaffID
            Teacher_3_id = $_.SectionStaffMembers[2].StaffID
            Teacher_4_id = $_.SectionStaffMembers[3].StaffID
            Teacher_5_id = $_.SectionStaffMembers[4].StaffID
            Teacher_6_id = $_.SectionStaffMembers[5].StaffID
            Teacher_7_id = $_.SectionStaffMembers[6].StaffID
            Teacher_8_id = $_.SectionStaffMembers[7].StaffID
            Teacher_9_id = $_.SectionStaffMembers[8].StaffID
            Teacher_10_id = $_.SectionStaffMembers[9].StaffID
            Name = $CourseHT[$_.CourseID].Title
            Section_number = $_.SectionNumber
            Grade = $_.HighGrade
            Course_name = $CourseHT[$_.CourseID].Title
            Course_number = $_.CourseID
            Course_description = $CourseHT[$_.CourseID].ContentDescription
            Period = $_.Period
            #Subject = $_ #May need to cross reference elsewhere
            Term_name = $Config.TermName #$_.Semester # ??? Maybe? Maybe we pull it from the school?
            Term_start = $Config.TermStart
            Term_end = $Config.TermEnd
            #ext.* Additional data sent over in extension field.
        }
    }

    # Format enrollment data for Clever
    $enrollments += $SummerRosters | ForEach-Object {
        [pscustomobject]@{
            School_id = $_.SchoolCode #Required
            Section_id = $_.SectionNumber #Required
            Student_id = $_.StudentID #Required
        }
    }
}

# Export Student Data to CSV
$NewStudents | export-csv -path "$ExportDirectory\Students.csv" -NoTypeInformation

# Export Teacher Data to CSV
$NewTeachers | export-csv -path "$ExportDirectory\Teachers.csv" -NoTypeInformation

# Export Section Data to CSV
$Sections | export-csv -path "$ExportDirectory\Sections.csv" -NoTypeInformation -Force

# Export Enrollment Data to CSV
$Enrollments | export-csv -path "$ExportDirectory\Enrollments.csv" -NoTypeInformation

Stop-Transcript