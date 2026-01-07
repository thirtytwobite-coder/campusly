# Program Management - Testing & Implementation Guide

## Quick Start Guide

### How to Access the Program Management Feature

1. **Log in as Club Coordinator**
   - Use your coordinator credentials
   - You'll be directed to the Coordinator Dashboard

2. **Navigate to Programs**
   - On the dashboard, look for the "Quick Actions" section
   - Click the "Programs" card with the event icon
   - You'll see the program management screen

### Creating a Program

#### Steps:
1. Click the **+** floating action button (bottom right)
2. Fill in the form:
   - **Program Name** * (required) - e.g., "Annual Tech Summit"
   - **Description** - Details about the program
   - **Date** * (required) - Click field to pick date
   - **Time** - Click field to pick time
   - **Location** - Event venue

3. Click **Create** button
4. Program appears in the list with "Pending" status

#### Validation Errors:
- Empty program name → "Program name cannot be empty"
- Empty date → "Date cannot be empty"
- Wrong date format → "Invalid date format. Use YYYY-MM-DD"

### Editing a Program

#### Steps:
1. Click the **edit icon** (pencil) on any program card
2. Modify the details
3. Click **Update** to save
4. Confirmation message appears

### Changing Program Status

#### Steps:
1. Locate the program card
2. Find the **Status Dropdown** (shows current status with color)
3. Select a new status:
   - Pending (Orange) - Not yet started
   - Ongoing (Blue) - Currently happening
   - Completed (Green) - Successfully finished
   - Cancelled (Red) - Event cancelled

4. Status updates immediately with visual feedback

### Deleting a Program

#### Steps:
1. Click the **delete icon** (trash) on any program card
2. Confirm deletion in the dialog
3. Program is removed permanently

## Testing Scenarios

### Test 1: Create Program with All Fields
**Expected:** Program created successfully
```
Name: "Coding Workshop"
Description: "Learn advanced Python"
Date: "2025-06-15"
Time: "14:30"
Location: "Room 101"
```
Result: Program appears with Pending status

### Test 2: Create Program - Missing Name
**Expected:** Error message
```
Click Create without entering name
Error: "Program name cannot be empty"
```

### Test 3: Create Program - Missing Date
**Expected:** Error message
```
Enter name but leave date empty
Error: "Date cannot be empty"
```

### Test 4: Create Program - Invalid Date Format
**Expected:** Error message
```
Enter date as "15-06-2025" (wrong format)
Error: "Invalid date format. Use YYYY-MM-DD"
```

### Test 5: Use Date Picker
**Expected:** Date picker appears
```
Click on Date field
System date picker opens
Select June 15, 2025
Field auto-fills with "2025-06-15"
```

### Test 6: Use Time Picker
**Expected:** Time picker appears
```
Click on Time field
System time picker opens
Select 2:30 PM
Field auto-fills with "14:30"
```

### Test 7: Change Program Status
**Expected:** Status updates immediately
```
1. Create program (default: Pending)
2. Click status dropdown
3. Select "Ongoing"
4. Badge changes to blue with "Ongoing"
5. Badge icon changes to play symbol
```

### Test 8: Status State Transitions
**Expected:** Can transition between all statuses
```
Pending → Ongoing → Completed ✓
Pending → Cancelled ✓
Ongoing → Completed ✓
Ongoing → Cancelled ✓
```

### Test 9: Edit Program Details
**Expected:** Program updates without changing status
```
1. Create program with Pending status
2. Click edit icon
3. Change name and description
4. Click Update
5. Changes saved, status remains Pending
```

### Test 10: Delete Program
**Expected:** Program removed from list
```
1. Create program
2. Click delete icon
3. Confirm in dialog
4. Program disappears from list
```

### Test 11: Empty State
**Expected:** User-friendly empty message
```
1. No programs created yet
2. Screen shows icon with "No programs created yet"
3. "Create First Program" button available
```

### Test 12: Multiple Programs Display
**Expected:** All programs listed with latest first
```
Create 3+ programs
View list - newest at top
All statuses, dates, times visible
```

### Test 13: Data Persistence
**Expected:** Data survives app restart
```
1. Create program with specific details
2. Close and restart app
3. Program still exists with same details
```

### Test 14: Concurrent Status Updates
**Expected:** Last update wins
```
1. Create program
2. Quickly change status multiple times
3. Final status is the last one selected
```

### Test 15: Special Characters in Name
**Expected:** Accepted and saved
```
Program Name: "Python & Django Workshop 2025"
Result: Saved and displayed correctly
```

## Unit Tests

### Running All Tests:
```bash
flutter test test/program_test.dart -v
```

### Test Groups:

#### 1. Program Form Validation Tests
- ✓ Empty name validation
- ✓ Empty date validation
- ✓ Invalid date format
- ✓ Valid form submission
- ✓ Whitespace trimming

#### 2. Date Format Tests
- ✓ Date formatting (YYYY-MM-DD)
- ✓ Date parsing from string
- ✓ Exception handling

#### 3. Status Badge Tests
- ✓ Color mapping (pending → orange)
- ✓ Color mapping (ongoing → blue)
- ✓ Color mapping (completed → green)
- ✓ Color mapping (cancelled → red)
- ✓ Icon mapping for all statuses

#### 4. Program Data Tests
- ✓ Program creation with all fields
- ✓ Status update functionality
- ✓ Status transition flow

#### 5. Time Format Tests
- ✓ Time formatting (HH:MM)
- ✓ Padding of single digits

## Key Features Verification

- [ ] **Form Validation** - Works as specified
- [ ] **Date Picker** - Selects dates correctly
- [ ] **Time Picker** - Selects times correctly
- [ ] **Status Colors** - Display correct colors
- [ ] **Status Icons** - Display correct icons
- [ ] **CRUD Operations** - Create, Read, Update, Delete all work
- [ ] **Error Messages** - Clear and helpful
- [ ] **Firebase Sync** - Data persists and syncs
- [ ] **Real-time Updates** - Changes appear immediately
- [ ] **Empty State** - Friendly message with action button
- [ ] **Responsive Design** - Works on different screen sizes
- [ ] **Dark Mode** - Theme switching works

## Troubleshooting

### Program Not Appearing After Creation
- Check Firebase connection
- Verify user is logged in as coordinator
- Look for error message in SnackBar
- Check Firestore database structure

### Date Picker Not Opening
- Ensure system locale is set correctly
- Check flutter version compatibility
- Verify intl package is installed

### Status Not Updating
- Check Firebase permissions for coordinator
- Verify status value is valid
- Check for network connectivity
- Look for error messages

### Performance Issues with Many Programs
- Consider pagination for large lists
- Check Firebase query performance
- Monitor app memory usage

## File Locations

- **Main Feature:** `lib/manage_programs.dart`
- **Tests:** `test/program_test.dart`
- **Documentation:** `PROGRAM_MANAGEMENT_DOCS.md`
- **Dashboard Integration:** `lib/club_coordinator_dashboard.dart`

## Firebase Rules Example

For security, ensure Firestore rules include:
```javascript
match /clubs/{clubId}/programs/{document=**} {
  allow read, write: if request.auth != null && 
    (request.auth.uid == resource.data.coordinatorId)
}
```

## Support

For detailed documentation, see `PROGRAM_MANAGEMENT_DOCS.md`
For technical questions, review the inline code comments in `manage_programs.dart`
