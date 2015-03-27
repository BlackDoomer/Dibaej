{ Initialization unit: defines tables and their columns in TIMETABLE.FDB }
unit def_tables;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface uses tables;

var
  tblClassrooms        : TTableInfo;
  tblGroups            : TTableInfo;
  tblGroupsSubjects    : TTableInfo;
  tblLessons           : TTableInfo;
  tblSubjects          : TTableInfo;
  tblTeachers          : TTableInfo;
  tblTeachersSubjects  : TTableInfo;
  tblWeekday           : TTableInfo;

  tblSummary           : TTableInfo;

implementation initialization

tblClassrooms := TTableInfo.Create( 'CLASSROOMS', 'Audiences' );
with tblClassrooms do begin
  AddColumn();
  AddColumn( 'NAME', 'No.' );
end;

tblGroups := TTableInfo.Create( 'GROUPS', 'Groups' );
with tblGroups do begin
  AddColumn();
  AddColumn( 'NAME', 'Code' );
end;

tblGroupsSubjects := TTableInfo.Create( 'GROUPS_SUBJECTS', 'Groups subjects' );
with tblGroupsSubjects do begin
  AddColumn(   'GROUP_ID', 'Group ID' );
  AddColumn( 'SUBJECT_ID', 'Subject ID' );
end;

tblLessons := TTableInfo.Create( 'LESSONS', 'Pairs timetable' );
with tblLessons do begin
  AddColumn(    'PAIR_ID', 'Pair ID' );
  AddColumn( 'WEEKDAY_ID', 'Weekday ID' );
  AddColumn(   'GROUP_ID', 'Group ID' );
  AddColumn( 'SUBJECT_ID', 'Subject ID' );
  AddColumn(   'CLASS_ID', 'Audience ID' );
  AddColumn( 'TEACHER_ID', 'Teacher ID' );
end;

tblSubjects := TTableInfo.Create( 'SUBJECTS', 'Subjects' );
with tblSubjects do begin
  AddColumn();
  AddColumn( 'NAME', 'Subject' );
end;

tblTeachers := TTableInfo.Create( 'TEACHERS', 'Teachers' );
with tblTeachers do begin
  AddColumn();
  AddColumn( 'NAME', 'Name' );
end;

tblTeachersSubjects := TTableInfo.Create( 'TEACHERS_SUBJECTS', 'Teachers subjects' );
with tblTeachersSubjects do begin
  AddColumn( 'TEACHER_ID', 'Teacher ID' );
  AddColumn( 'SUBJECT_ID', 'Subject ID' );
end;

tblWeekday := TTableInfo.Create( 'WEEKDAY', 'Weekdays' );
with tblWeekday do begin
  AddColumn();
  AddColumn( 'WEEKDAY', 'Weekday' );
end;

tblSummary := TTableInfo.Create( 'LESSONS', '-= Timetable Summary =-' );
with tblSummary do begin
  AddColumn( 'PAIR_ID', 'Pair No.' );
  AddColumn( 'WEEKDAY', 'Weekday',   0, tblWeekday,    'WEEKDAY_ID' );
  AddColumn(    'NAME', 'Group No.', 0, tblGroups,     'GROUP_ID'   );
  AddColumn(    'NAME', 'Subject',   0, tblSubjects,   'SUBJECT_ID' );
  AddColumn(    'NAME', 'Audience',  0, tblClassrooms, 'CLASS_ID'   );
  AddColumn(    'NAME', 'Teacher',   0, tblTeachers,   'TEACHER_ID' );
end;

end.

