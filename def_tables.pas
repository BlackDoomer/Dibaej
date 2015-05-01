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
  AddColumn( True, 'NAME', 'No.', DT_STRING );
end;

tblGroups := TTableInfo.Create( 'GROUPS', 'Groups' );
with tblGroups do begin
  AddColumn();
  AddColumn( True, 'NAME', 'Code', DT_STRING );
end;

{
tblLessons := TTableInfo.Create( 'LESSONS', 'Pairs timetable' );
with tblLessons do begin
  AddColumn( True,    'PAIR_ID', 'Pair ID',     DT_NUMERIC );
  AddColumn( True, 'WEEKDAY_ID', 'Weekday ID',  DT_NUMERIC );
  AddColumn( True,   'GROUP_ID', 'Group ID',    DT_NUMERIC );
  AddColumn( True, 'SUBJECT_ID', 'Subject ID',  DT_NUMERIC );
  AddColumn( True,   'CLASS_ID', 'Audience ID', DT_NUMERIC );
  AddColumn( True, 'TEACHER_ID', 'Teacher ID',  DT_NUMERIC );
end;
}
tblSubjects := TTableInfo.Create( 'SUBJECTS', 'Subjects' );
with tblSubjects do begin
  AddColumn();
  AddColumn( True, 'NAME', 'Subject', DT_STRING, 192 );
end;

tblTeachers := TTableInfo.Create( 'TEACHERS', 'Teachers' );
with tblTeachers do begin
  AddColumn();
  AddColumn( True, 'NAME', 'Name', DT_STRING, 192 );
end;

tblWeekday := TTableInfo.Create( 'WEEKDAY', 'Weekdays' );
with tblWeekday do begin
  AddColumn();
  AddColumn( True, 'WEEKDAY', 'Weekday', DT_STRING );
end;

tblGroupsSubjects := TTableInfo.Create( 'GROUPS_SUBJECTS', 'Groups subjects' );
with tblGroupsSubjects do begin
  //AddColumn( True,   'GROUP_ID', 'Group ID',   DT_NUMERIC );
  //AddColumn( True, 'SUBJECT_ID', 'Subject ID', DT_NUMERIC );
  AddColumn( True, 'NAME', 'Group No.', DT_STRING, 0, tblGroups,     'GROUP_ID' );
  AddColumn( True, 'NAME', 'Subject',   DT_STRING, 192, tblSubjects, 'SUBJECT_ID' );
end;

tblTeachersSubjects := TTableInfo.Create( 'TEACHERS_SUBJECTS', 'Teachers subjects' );
with tblTeachersSubjects do begin
  //AddColumn( True, 'TEACHER_ID', 'Teacher ID', DT_NUMERIC );
  //AddColumn( True, 'SUBJECT_ID', 'Subject ID', DT_NUMERIC );
  AddColumn( True, 'NAME', 'Teacher', DT_STRING, 192, tblTeachers, 'TEACHER_ID' );
  AddColumn( True, 'NAME', 'Subject', DT_STRING, 192, tblSubjects, 'SUBJECT_ID' );
end;

tblSummary := TTableInfo.Create( 'LESSONS', '-= Timetable Summary =-' );
with tblSummary do begin
  AddColumn( True, 'PAIR_ID', 'Pair No.',  DT_NUMERIC );
  AddColumn( True, 'WEEKDAY', 'Weekday',   DT_STRING, 0,   tblWeekday,    'WEEKDAY_ID' );
  AddColumn( True,    'NAME', 'Group No.', DT_STRING, 0,   tblGroups,     'GROUP_ID'   );
  AddColumn( True,    'NAME', 'Subject',   DT_STRING, 192, tblSubjects,   'SUBJECT_ID' );
  AddColumn( True,    'NAME', 'Audience',  DT_STRING, 0,   tblClassrooms, 'CLASS_ID'   );
  AddColumn( True,    'NAME', 'Teacher',   DT_STRING, 192, tblTeachers,   'TEACHER_ID' );
end;

end.

