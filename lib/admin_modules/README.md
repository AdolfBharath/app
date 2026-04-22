# Admin Modules - Modular Architecture

This document describes the modular structure of the admin side of the application.

## Directory Structure

```
lib/admin_modules/
├── shared/                 # Shared widgets and utilities
│   ├── card_action_button.dart
│   ├── admin_form_field.dart
│   ├── detail_item.dart
│   └── index.dart
├── course/                 # Course management module
│   ├── course_card.dart
│   ├── course_view_dialog.dart
│   ├── course_edit_dialog.dart
│   └── index.dart
├── user/                   # User management module
│   ├── user_card.dart
│   ├── user_view_dialog.dart
│   ├── user_edit_dialog.dart
│   └── index.dart
└── batch/                  # Batch management module
    ├── batch_card.dart
    ├── batch_view_dialog.dart
    ├── batch_edit_dialog.dart
    └── index.dart
```

## Module Organization

### Shared Module (`admin_modules/shared/`)

Reusable components used across all admin modules:

- **CardActionButton**: Button component for View/Edit/Delete actions on cards
- **AdminFormField**: Form field widget for admin dialogs with validation
- **DetailItem**: Display item for showing key-value pairs in dialogs

### Course Module (`admin_modules/course/`)

Course management components:

- **CourseCard**: Displays course information with actions
- **CourseViewDialog**: Modal for viewing course details
- **CourseEditDialog**: Modal form for editing course information

### User Module (`admin_modules/user/`)

User management components:

- **UserCard**: Displays user information with role badge and actions
- **UserViewDialog**: Modal for viewing user details
- **UserEditDialog**: Modal form for editing user information

### Batch Module (`admin_modules/batch/`)

Batch management components:

- **BatchCard**: Displays batch information with status and student count
- **BatchViewDialog**: Modal for viewing batch details
- **BatchEditDialog**: Modal form for editing batch information

## Benefits of Modular Architecture

1. **Separation of Concerns**: Each module handles its own UI components
2. **Reusability**: Shared components can be used across multiple modules
3. **Maintainability**: Easier to locate and update specific functionality
4. **Testability**: Components can be tested independently
5. **Scalability**: Easy to add new modules following the same pattern
6. **Code Organization**: Clear directory structure makes navigation easier

## Usage Example

```dart
// Import shared widgets
import 'admin_modules/shared/index.dart';

// Import course module
import 'admin_modules/course/index.dart';

// Use in your screen
return CourseCard(
  course: course,
  onDelete: () => _deleteCourse(course),
  onView: () => showDialog(builder: (_) => CourseViewDialog(course: course)),
  onEdit: () => showDialog(builder: (_) => CourseEditDialog(course: course)),
);
```

## Integration with Screen Files

The screen files (`manage_course_screen.dart`, `manage_user_screen.dart`, `manage_batch_screen.dart`) now use the modular components:

- Screens remain focused on data loading and state management
- UI components are extracted to separate, reusable files
- Dialogs are encapsulated in their own files
- Common widgets are shared through the shared module

## Adding New Features

To add new management features:

1. Create a new folder in `admin_modules/`
2. Create component files following the pattern (Card, ViewDialog, EditDialog, index.dart)
3. Create shared dialogs/components in `admin_modules/shared/`
4. Update the screen file to use the new modular components

This architecture promotes clean code and maintainability throughout the admin section.
