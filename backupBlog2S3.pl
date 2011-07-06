#!/usr/bin/perl

# configure temporary directory which has to be writable to the user
my $tmp_dir = "<TEMP DIR>";
my $archive_dir = "<LOCAL ARCHIVE DIR>";

# configure Amazon S3 storage access
$ENV{'AWS_ACCESS_KEY_ID'}="";
$ENV{'AWS_SECRET_ACCESS_KEY'}="";
my $backup_destination_root="s3+http://";


# configure GPG keychain
$ENV{'PASSPHRASE'}='';
# key ID to encrypt the backup. Has to be in the keychain of the user running this script
my $gpg_key_ID="";

my $log_file = "";

# here we start with the backup tasks
# use a backup_directory_tree function to backup parts of the file system
# use dump_MySQL to backup a database by dumping it first and then backing it up

&dump_MySQL("<db_user>","<db_pw>","<database_name>");
&backup_directory_tree("/var/www/htdocs", "homepage", "1M", "14D", "homepage","/var/www/htdocs/cache");


# usage dump_MySQL(db_user, db_passwd, db, temp_file)
# temp_file is optional
sub dump_MySQL
{
    my $db_user = shift;
    my $db_passwd = shift;
    my $db = shift;
    my $temp_file;
    if (scalar(@_)==1) {
        $temp_file = shift;
    } else {
        $temp_file = "$tmp_dir/$db/${db}_dump.sql";
        system("mkdir $tmp_dir/$db") unless (-d "$tmp_dir/$db");
    }
    # removing the SQL dump
    `rm $temp_file` if (-e $temp_file);
    my $dump_command = "mysqldump --lock-tables --complete-insert "
    ."--add-drop-table --quick --quote-names -u $db_user -p$db_passwd "
    ."--databases $db >$temp_file";
    my $result = system($dump_command);
    return $result;
}

# usage backup_directory_tree($directory, $backup_name, $oldest_backup, $full_backup_interval, $s3_upload_folder)
sub backup_directory_tree
{
    my $directory = shift;
    my $backup_name = shift;
    my $oldest_backup = shift;
    my $full_backup_interval = shift;
    my $s3_upload_folder = shift;
    # if there is an exclude directory given, use it
    if (scalar(@_)==1) my $exclude_directory = shift;
    # Delete any backups older than $oldest_backup
    my $remove_log = `duplicity remove-older-than $oldest_backup --s3-use-new-style --name $backup_name --encrypt-key=$gpg_key_ID --sign-key=$gpg_key_ID --archive-dir $archive_dir $backup_destination_root/$directory`;
    # Make the regular backup
    # Will be a full backup if past the older-than parameter
    my $backup_command = "duplicity --full-if-older-than $full_backup_interval --s3-use-new-style --name $backup_name --encrypt-key=$gpg_key_ID --sign-key=$gpg_key_ID --archive-dir $archive_dir $directory $backup_destination_root/$s3_upload_folder";
    $backup_command .= " --exclude $exclude_directory" if (defined($exclude_directory));
    my $backup_log=`$backup_command`;
    open my $log, ">>", $log_file;
    print $log $backup_log;
    close $log;
}
