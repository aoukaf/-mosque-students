# ⚡ Quick Start Guide - Mosque Management

## 🚀 Get Started in 5 Minutes

### Step 1: Create Your First Mosque 🕌

1. Open the app
2. Tap the **🕌 mosque icon** in the top toolbar
3. Tap **"مسجد جديد"** (New Mosque)
4. Fill in the form:
   - **اسم المسجد**: Mosque Al-Noor
   - **الموقع**: Algiers
   - **المشرف**: Your Name
   - **الهاتف**: (Optional)
5. Tap **"إنشاء"** (Create)

✅ **Done!** Firebase automatically generated a unique ID for your mosque.

---

### Step 2: Add Students to Your Mosque 👥

You can now add students as usual using the **➕ Add Student** button. They will automatically be saved under your mosque's ID in the database.

---

### Step 3: Transfer Students to Another Mosque 📤

#### To move a student to another mosque:

1. Tap the **📤 transfer icon** in the toolbar
2. Select **المسجد المصدر** (Source Mosque) - where the student is now
3. Select **المسجد المقصد** (Destination Mosque) - where you want to send them
4. Choose **نقل** (Transfer) - removes from source
5. Select the student(s) from the list
6. Tap **"نقل X طالب/ة"**
7. Confirm the operation

✅ **Student moved!** Automatically recorded in transfer logs.

---

## 🎯 Common Scenarios

### Scenario A: Single Mosque
- Just create one mosque
- Use it like before
- Everything is automatically organized under that mosque's ID

### Scenario B: Multiple Mosque Branches
- Create a mosque for each branch
- Each has its own students and data
- Use **Transfer** to move students between branches

### Scenario C: Combine Data from Multiple Mosques
- Create a new "Central" mosque
- Use **Copy** (not Transfer) to duplicate students from branch mosques
- Now you have a master list

---

## 📱 Navigation

| Icon | Name | Function |
|------|------|----------|
| 📊 | Statistics | View charts and analytics |
| ✓ | Attendance | Track daily attendance |
| 👥 | Halqas | Manage student groups |
| 🕌 | **NEW:** Mosques | Create and manage mosques |
| 📤 | **NEW:** Transfer | Move students between mosques |

---

## 🔑 Key Concepts

### Firebase ID
- **Auto-generated** by Firebase when you create a mosque
- **Unique** - no two mosques have the same ID
- **Permanent** - cannot be changed
- **Copy it** if you need to share it with others

### Collection Structure
```
Each mosque has:
├── Its own students collection
├── Its own halqas/groups
├── Separate data from other mosques
└── No interference with other mosques' data
```

### Transfer vs Copy
- **Transfer**: Move student (gone from source, appears in destination)
- **Copy**: Duplicate student (stays in source, also appears in destination)

---

## ⚠️ Important Notes

✅ **Local Backup**: Automatically saves locally - works offline  
✅ **Atomic Operations**: Transfer either fully succeeds or fully fails  
✅ **Logged**: Every transfer is recorded in Firebase  
✅ **Reversible**: You can always transfer back if needed  

❌ **Deleting a mosque**: Deletes all its students - be careful!  
❌ **Same ID issue**: Can't have duplicate student IDs in same mosque  
❌ **Data isolation**: One mosque can't directly access another's students  

---

## 🆘 Troubleshooting

### "Mosque not found"
- Check the mosque ID is correct
- Make sure internet is connected
- Refresh the app

### "Student already exists"
- Can't add a student with same ID twice to same mosque
- Use **Copy** if you want duplicate from another mosque

### "Transfer failed"
- Check both mosques exist
- Check student is in source mosque
- Try again with internet connection

### "Offline mode"
- All changes are saved locally
- Will sync when internet returns
- Status bar shows sync status

---

## 📚 Learn More

- **User Guide**: See `MOSQUE_MANAGEMENT.md` for detailed features
- **API Docs**: See `MOSQUE_API.md` for developer information
- **Code Examples**: See `CODE_EXAMPLES.md` for implementation details

---

## 🎓 Next Steps

1. ✅ Create your mosque
2. ✅ Add some students
3. ✅ Try transferring a student
4. ✅ Check the database structure
5. ✅ Read the full documentation

---

## 💡 Pro Tips

**Tip 1**: Keep the mosque ID safe - it's unique and permanent

**Tip 2**: Use meaningful names and supervisor info - helps when sharing

**Tip 3**: Copy students before deleting a mosque - preserves data

**Tip 4**: Check statistics to see students per halqa

**Tip 5**: Use Transfer Log to audit all student movements

---

**Version**: 2.0.0  
**Updated**: 2026-05-06  
**Status**: ✅ Ready to use
