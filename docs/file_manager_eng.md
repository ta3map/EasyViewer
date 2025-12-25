# File Manager

File manager with SQL database support for organizing projects, file groups, and metadata.

![File Manager main window](screenshots/placeholder_file_manager_main.png)

## Database Structure

File Manager uses SQLite database to store information about projects, groups, files, and analysis results.

### Database Tables

- **projects** - projects
- **groups** - file groups within projects
- **group_metadata** - group metadata
- **files** - files
- **project_files** - project-file relationship (many-to-many)
- **file_metadata** - file metadata
- **analysis_results** - module analysis results

Detailed schema description: [SQL Storage](sql_storage_eng.md)

## Database Selection

The top of the window displays the path to the current database. The **Select Database** button allows selecting an existing database or creating a new one.

![Database selection](screenshots/placeholder_file_manager_database.png)

## Projects

### Creating Project

The **New Project** button opens a dialog for creating a new project. Specify the project name and description.

![Creating project](screenshots/placeholder_file_manager_new_project.png)

### Projects List

The left panel contains a list of all projects in the database. Selecting a project loads its files and groups.

![Projects list](screenshots/placeholder_file_manager_projects_list.png)

### Editing Project

Select a project and use the **Edit Project** button to change the name and description.

### Deleting Project

Select a project and use the **Delete Project** button to delete it. All associated groups, files, and results are deleted.

## Groups

### Creating Group

The **New Group** button creates a new group in the current project. Specify the group name.

![Creating group](screenshots/placeholder_file_manager_new_group.png)

### Groups List

The middle panel contains a list of groups in the current project. Selecting a group filters files by group.

![Groups list](screenshots/placeholder_file_manager_groups_list.png)

### Editing Group

Select a group and use the **Edit Group** button to change the name.

### Deleting Group

Select a group and use the **Delete Group** button to delete it. Files remain in the project but lose association with the group.

### Group Metadata

The **Group Metadata** button opens the group metadata editing window. Metadata is stored as field-value pairs.

![Group metadata](screenshots/placeholder_file_manager_group_metadata.png)

## Files

### Adding Files

The **Add File** button opens a file selection dialog. Selected files are added to the current project.

![Adding files](screenshots/placeholder_file_manager_add_file.png)

### Files List

The right panel contains a list of files in the current project. The table shows:

- File path
- File name
- Group (if assigned)
- Metadata (if set)

![Files list](screenshots/placeholder_file_manager_files_list.png)

### Assigning Group

Select file(s) in the list and use the **Assign to Group** dropdown to assign a group.

### File Metadata

Select a file and use the **File Metadata** button to edit file metadata.

![File metadata](screenshots/placeholder_file_manager_file_metadata.png)

### Removing File

Select a file and use the **Remove File** button to remove it from the project. The file remains in the database but loses association with the project.

### Opening File

Select a file and use the **Open File** button to open it in Signal Viewer or Signal Analysis (depending on context).

## Automation Modules

### Module Selection

The **Module** dropdown contains available automation modules:

- **autoClusterPermutationTest** - cluster permutation test
- **autoMeanStimulus** - averaging by stimuli
- **autoDetectStimuli** - automatic stimulus detection
- **autoSlopeMeasurement** - automatic slope measurement

![Module selection](screenshots/placeholder_file_manager_module_selection.png)

### Module Parameters Configuration

The **Edit Module Params** button opens the parameter editing window for the selected module. Parameters are saved in JSON format.

![Module parameters configuration](screenshots/placeholder_file_manager_module_params.png)

### Running Module

The **Run Module** button runs the selected module for selected files. Results are saved to the database and displayed in the results list.

![Running module](screenshots/placeholder_file_manager_run_module.png)

### Module Queue

Modules can be added to a queue for sequential execution. The **Add to Queue** button adds the current module configuration to the queue.

## Analysis Results

### Viewing Results

Select a file and use the **View Results** button to view analysis results. A list of all results for the selected file is displayed.

![Viewing results](screenshots/placeholder_file_manager_view_results.png)

### Deleting Results

Select a result and use the **Delete Result** button to delete it from the database.

## Excel Import

The **Import from Excel** button allows importing a file list from an Excel table. Specify the column with file paths.

![Excel import](screenshots/placeholder_file_manager_import_excel.png)

## Export

The **Export** button allows exporting the file list of the current project to an Excel table.

## Filtering and Search

The **Search** field allows filtering files by name or path.

![File search](screenshots/placeholder_file_manager_search.png)

## Settings

The **Settings** button opens the File Manager settings window:

- Default database path
- Display settings
- Module settings

![File Manager settings](screenshots/placeholder_file_manager_settings.png)

