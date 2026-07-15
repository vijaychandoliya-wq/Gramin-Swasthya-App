from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs"
OUT.mkdir(exist_ok=True)

GREEN = "176B4D"
PALE = "EAF5EF"
INK = "1B2822"
MUTED = "52645B"
RULE = "C9DDD1"


def shade(cell, color):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), color)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def set_table_widths(table, widths):
    table.autofit = False
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for row in table.rows:
        for idx, width in enumerate(widths):
            cell = row.cells[idx]
            cell.width = Inches(width)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_margins(cell)
            tc_pr = cell._tc.get_or_add_tcPr()
            tc_w = tc_pr.find(qn("w:tcW"))
            if tc_w is None:
                tc_w = OxmlElement("w:tcW")
                tc_pr.append(tc_w)
            tc_w.set(qn("w:w"), str(int(width * 1440)))
            tc_w.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def style_doc(doc, short_title):
    sec = doc.sections[0]
    sec.top_margin = Inches(0.65)
    sec.bottom_margin = Inches(0.55)
    sec.left_margin = Inches(0.8)
    sec.right_margin = Inches(0.8)
    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Aptos"
    normal.font.size = Pt(10)
    normal.font.color.rgb = RGBColor.from_string(INK)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.05
    for name, size, color in [("Heading 1", 17, GREEN), ("Heading 2", 13, INK), ("Heading 3", 11, GREEN)]:
        s = styles[name]
        s.font.name = "Aptos Display"
        s.font.size = Pt(size)
        s.font.bold = True
        s.font.color.rgb = RGBColor.from_string(color)
        s.paragraph_format.space_before = Pt(11)
        s.paragraph_format.space_after = Pt(5)
        s.paragraph_format.keep_with_next = True
    footer = sec.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    r = footer.add_run(f"{short_title}  •  Gramin Swasthya")
    r.font.size = Pt(8)
    r.font.color.rgb = RGBColor.from_string(MUTED)


def title_block(doc, title, subtitle):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run(title)
    r.font.name = "Aptos Display"
    r.font.size = Pt(25)
    r.font.bold = True
    r.font.color.rgb = RGBColor.from_string(GREEN)
    p = doc.add_paragraph(subtitle)
    p.paragraph_format.space_after = Pt(12)
    p.runs[0].font.size = Pt(12)
    p.runs[0].font.color.rgb = RGBColor.from_string(MUTED)
    table = doc.add_table(rows=1, cols=2)
    set_table_widths(table, [2.0, 4.8])
    for cell in table.rows[0].cells:
        shade(cell, PALE)
    table.cell(0, 0).text = "Document owner"
    table.cell(0, 1).text = "Gramin Swasthya product and engineering team"
    for cell in table.rows[0].cells:
        for p in cell.paragraphs:
            p.paragraph_format.space_after = Pt(0)
            for run in p.runs:
                run.font.size = Pt(9)
                run.font.color.rgb = RGBColor.from_string(MUTED)
    doc.add_paragraph()


def add_bullets(doc, items):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.paragraph_format.space_after = Pt(3)
        p.add_run(item)


def add_numbered(doc, items):
    for item in items:
        p = doc.add_paragraph(style="List Number")
        p.paragraph_format.space_after = Pt(3)
        p.add_run(item)


def add_table(doc, headers, rows, widths):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    set_table_widths(table, widths)
    hdr = table.rows[0]
    set_repeat_table_header(hdr)
    for i, text in enumerate(headers):
        shade(hdr.cells[i], GREEN)
        p = hdr.cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        run = p.add_run(text)
        run.font.bold = True
        run.font.color.rgb = RGBColor(255, 255, 255)
        run.font.size = Pt(9)
    for row_data in rows:
        row = table.add_row()
        for i, text in enumerate(row_data):
            if len(table.rows) % 2 == 0:
                shade(row.cells[i], "F6FAF7")
            row.cells[i].text = str(text)
            for p in row.cells[i].paragraphs:
                p.paragraph_format.space_after = Pt(1)
                for run in p.runs:
                    run.font.size = Pt(9)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def add_callout(doc, label, text):
    table = doc.add_table(rows=1, cols=1)
    set_table_widths(table, [6.8])
    cell = table.cell(0, 0)
    shade(cell, PALE)
    p = cell.paragraphs[0]
    r = p.add_run(label + "  ")
    r.bold = True
    r.font.color.rgb = RGBColor.from_string(GREEN)
    p.add_run(text)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)


def make_srs():
    doc = Document()
    style_doc(doc, "SRS")
    title_block(doc, "Software Requirements Specification", "Gramin Swasthya — rural family health tracking application")
    add_callout(doc, "Purpose", "This SRS defines the functional, non-functional, security, data, and acceptance requirements for the Flutter application, including the SQLCipher-encrypted offline database introduced in this implementation.")
    doc.add_heading("1. Introduction", level=1)
    doc.add_heading("1.1 Scope", level=2)
    doc.add_paragraph("Gramin Swasthya is an offline-first Flutter mobile application for Indian families to record health measurements, manage medicines, store medical reports, receive reminders, and share selected information with doctors. The application supports multiple Indian languages, local SQLite-style persistence, optional Google authentication and Drive backup, and Android/iOS distribution.")
    doc.add_heading("1.2 Product objectives", level=2)
    add_bullets(doc, ["Provide simple, accessible health record keeping for rural and multilingual households.", "Keep core records available without network connectivity.", "Protect locally stored health information using SQLCipher AES database encryption.", "Allow family-member-specific records, medicines, reports, and summaries.", "Support a release package suitable for Play Store delivery."])
    doc.add_heading("1.3 Definitions and references", level=2)
    add_table(doc, ["Term", "Meaning"], [("Member", "A person in the household whose health data is tracked."), ("SQLCipher", "An SQLite-compatible database engine that encrypts database pages using a key-derived encryption key."), ("Offline-first", "Core read/write workflows continue without an active network connection."), ("SRS", "Software Requirements Specification."), ("BRD", "Business Requirements Document.")], [1.6, 5.2])
    doc.add_paragraph("Technical references: SQLCipher project documentation (github.com/sqlcipher/sqlcipher); sqflite_sqlcipher package documentation (pub.dev/packages/sqflite_sqlcipher).")
    doc.add_heading("2. Overall description", level=1)
    doc.add_heading("2.1 User classes", level=2)
    add_table(doc, ["User", "Needs"], [("Primary family user", "Manage family profiles, measurements, medicines, reports, backups, and settings."), ("Family member", "View or contribute health records when selected by the primary user."), ("Doctor / recipient", "Receive an intentionally shared subset of records through QR or sharing flows."), ("Administrator / support", "Diagnose release issues without accessing plaintext health records.")], [1.8, 5.0])
    doc.add_heading("2.2 System context", level=2)
    doc.add_paragraph("The Flutter client contains the presentation layer, Riverpod providers, GoRouter navigation, local persistence, notification scheduling, media handling, Firebase integrations, and language packs. SQLite data is encrypted on Android/iOS through sqflite_sqlcipher. Web/test execution uses the existing in-memory MockDatabase because the native SQLCipher plugin is mobile-focused.")
    doc.add_heading("3. Functional requirements", level=1)
    fr = [("FR-01", "Onboarding and language", "The system shall allow a user to select an available language and persist that choice locally."), ("FR-02", "Family profiles", "The system shall create, edit, select, and delete family members and support profile photos and emergency details."), ("FR-03", "Health measurements", "The system shall record BP, sugar, and weight entries associated with a selected member, with date/time and notes."), ("FR-04", "Health visualization", "The system shall show member-specific history, ranges, summaries, and charts for health data."), ("FR-05", "Medicines", "The system shall create medicines, dosage/timing schedules, active status, taken history, and adherence summaries."), ("FR-06", "Notifications", "The system shall schedule and cancel local medicine reminders according to user settings and active medicine state."), ("FR-07", "Reports", "The system shall capture, filter, view, search, and organize prescription, lab, X-ray, and other report records."), ("FR-08", "Sharing", "The system shall generate controlled sharing/QR flows without exposing records not selected by the user."), ("FR-09", "Backup", "The system shall support optional Google Drive profile backup and restore after authenticated user action."), ("FR-10", "Encrypted persistence", "The system shall open mobile local storage with a SQLCipher password and shall not expose the database key in source code, logs, or user-visible UI."), ("FR-11", "Migration", "On first encrypted launch, the system shall migrate an existing plaintext database into a new encrypted database before deleting the temporary plaintext backup."), ("FR-12", "Failure handling", "If the key is unavailable or database authentication fails, the system shall fail closed and show a recoverable error path rather than opening plaintext storage.")]
    add_table(doc, ["ID", "Area", "Requirement"], fr, [0.7, 1.45, 4.65])
    doc.add_heading("4. Data and security requirements", level=1)
    doc.add_heading("4.1 Local data model", level=2)
    add_table(doc, ["Table", "Purpose"], [("family_members", "Member identity, relationship, contact, emergency, and photo metadata."), ("bp_readings", "Systolic, diastolic, pulse, notes, timestamps, sync state."), ("sugar_readings", "Measurement type, value, notes, timestamps, sync state."), ("weight_entries", "Weight, optional height, notes, timestamps, sync state."), ("medical_reports", "Type, local path, remote URL, doctor, date, notes, sync state."), ("medicines", "Name, dosage, times, duration, active state, sync state."), ("medicine_log", "Scheduled time, taken time, status, sync state.")], [1.8, 5.0])
    doc.add_heading("4.2 SQLCipher key lifecycle", level=2)
    add_numbered(doc, ["Generate 32 cryptographically secure random bytes on first mobile database initialization and encode them for storage.", "Store the key in flutter_secure_storage, backed by Android Keystore/iOS Keychain where supported.", "Open GraminSwasthya.db through sqflite_sqlcipher with the password before application queries run.", "Never store the key in SharedPreferences, SQLite, source code, analytics, crash logs, or debug output.", "If the secure key is deleted, do not silently create a new empty database; require an explicit recovery/reset flow."])
    add_callout(doc, "Migration caution", "The migration path temporarily creates a .plaintext-backup file while copying existing rows into the encrypted database. The implementation deletes that file only after successful import; production QA must test interruption, low storage, process death, and backup exclusion behavior.")
    doc.add_heading("5. Non-functional requirements", level=1)
    nfr = [("NFR-01", "Performance", "Typical local read/write operations should complete within 500 ms on a supported mid-range Android device."), ("NFR-02", "Availability", "Core member, measurement, medicine, and report workflows shall work without network access."), ("NFR-03", "Security", "Mobile database files shall be unreadable as plaintext SQLite without the secure key."), ("NFR-04", "Privacy", "Health data shall not be included in logs or analytics by default."), ("NFR-05", "Accessibility", "Controls shall have readable labels, adequate touch targets, and support localized text expansion."), ("NFR-06", "Compatibility", "Android min SDK shall remain 24; iOS and supported Flutter targets shall be verified in CI."), ("NFR-07", "Maintainability", "Database schema changes shall increment the version and include an upgrade path."), ("NFR-08", "Release", "Release builds shall use R8/resource shrinking and SQLCipher keep rules without breaking database access.")]
    add_table(doc, ["ID", "Quality attribute", "Requirement"], nfr, [0.7, 1.35, 4.75])
    doc.add_heading("6. Acceptance criteria", level=1)
    add_bullets(doc, ["A fresh Android install creates an encrypted database and can create/read/update/delete records.", "A seeded legacy plaintext database migrates successfully and the resulting file cannot be opened by normal SQLite without the key.", "Deleting app data and reinstalling creates a new key and empty database without reusing a previous key.", "All existing Flutter tests pass; new encryption tests cover fresh creation, wrong key failure, migration, and secure-key absence.", "Release Android build completes with R8 and includes net.sqlcipher classes required by the plugin.", "Language selection, profile selection, notifications, reports, and Google Drive flows continue to work after encryption is enabled."])
    doc.add_heading("7. Risks and open decisions", level=1)
    add_bullets(doc, ["The current project toolchain is Flutter 3.22/Dart 3.4, so sqflite_sqlcipher is pinned to 3.2.0 rather than the latest package release.", "The normal sqflite dependency remains for the one-time migration API; iOS CocoaPods integration must be validated because FMDB and SQLCipher variants can conflict.", "Secure storage backup/restore behavior differs by platform and must be tested on real devices.", "SQLCipher protects the database at rest; it does not protect data while displayed, in memory, or after intentional export/share."])
    doc.add_heading("Appendix A — implementation touchpoints", level=1)
    add_bullets(doc, ["lib/db/database_helper.dart — encrypted open, key lifecycle, schema, migration, and mock database.", "pubspec.yaml — sqflite_sqlcipher and flutter_secure_storage dependencies.", "android/app/proguard-rules.pro — SQLCipher and Flutter release keep rules.", "android/app/build.gradle.kts — release shrinking and resource shrinking."])
    doc.save(OUT / "Gramin_Swasthya_SRS.docx")


def make_brd():
    doc = Document()
    style_doc(doc, "BRD")
    title_block(doc, "Business Requirements Document", "Gramin Swasthya — secure, multilingual family health records")
    add_callout(doc, "Executive summary", "Gramin Swasthya gives Indian families a practical way to track health records, medicines, reports, and reminders on a mobile phone. The business priority for this release is to preserve offline usability while reducing privacy risk through encrypted local storage.")
    doc.add_heading("1. Business context", level=1)
    doc.add_paragraph("Families often manage health information across paper notes, messaging apps, and disconnected prescriptions. This makes history difficult to retrieve, medicine adherence difficult to monitor, and doctor sharing inconsistent. Gramin Swasthya consolidates these activities into a simple, multilingual mobile experience designed for family use and intermittent connectivity.")
    doc.add_heading("1.1 Problem statement", level=2)
    add_bullets(doc, ["Health records are fragmented across household members and providers.", "Many users need regional-language labels and simple visual summaries.", "Connectivity may be unavailable at the moment a record is needed.", "A lost or inspected phone can expose sensitive health information if local storage is plaintext.", "Large release artifacts and inconsistent UI patterns increase adoption and support cost."])
    doc.add_heading("1.2 Goals and success measures", level=2)
    add_table(doc, ["Goal", "Success measure"], [("Trusted local storage", "Mobile database is SQLCipher-encrypted; no plaintext database remains after successful migration."), ("Usable offline workflow", "Users can create and view core records without network access."), ("Multilingual reach", "Supported language packs render complete localized labels without mixed bilingual strings."), ("Family-centric experience", "Member selection consistently scopes health, medicine, and report data."), ("Store readiness", "Release build uses R8/resource shrinking and fits the project’s target size envelope."), ("Safe sharing", "Users explicitly choose what to share with doctors or family recipients.")], [2.0, 4.8])
    doc.add_heading("2. Stakeholders", level=1)
    add_table(doc, ["Stakeholder", "Interest / responsibility"], [("Families and caregivers", "Record data, manage medicines, and retrieve history."), ("Primary account holder", "Own household profiles, backups, and sharing permissions."), ("Clinicians", "Receive legible, relevant records and reports."), ("Product owner", "Prioritize adoption, trust, and feature outcomes."), ("Engineering", "Implement Flutter UI, persistence, integrations, release builds, and migration."), ("QA / release", "Validate supported devices, localization, migration, encryption, and store artifacts."), ("Privacy / security reviewer", "Review key management, backup boundaries, logging, and incident handling.")], [1.8, 5.0])
    doc.add_heading("3. Business requirements", level=1)
    br = [("BR-01", "Accessible health tracking", "The product must make common health tracking understandable to families with varied literacy and language needs."), ("BR-02", "Offline continuity", "The product must remain useful when internet connectivity is unavailable or unreliable."), ("BR-03", "Privacy by default", "Personal health information must be protected on the device without requiring technical setup by the user."), ("BR-04", "Family-level organization", "Users must be able to distinguish records for multiple household members."), ("BR-05", "Medication adherence", "Users must be reminded about active medicines and see whether scheduled doses were taken."), ("BR-06", "Doctor collaboration", "Users must be able to share relevant health information and reports intentionally."), ("BR-07", "Recovery and continuity", "Users must have an optional authenticated backup/restore path for profile data."), ("BR-08", "Sustainable release", "The app must control binary size, dependency growth, and platform-specific build risk."), ("BR-09", "Consistent interaction design", "Profile controls, member selectors, toggles, and navigation must behave consistently across screens.")]
    add_table(doc, ["ID", "Business need", "Requirement"], br, [0.7, 1.55, 4.55])
    doc.add_heading("4. Scope", level=1)
    doc.add_heading("4.1 In scope", level=2)
    add_bullets(doc, ["Flutter mobile application for Android and iOS.", "Onboarding, language selection, Google sign-in, and family profile management.", "BP, sugar, and weight records with history and charts.", "Medicine schedules, active/inactive state, taken logs, adherence, and notifications.", "Medical report capture, list/grid views, filters, search, and viewing.", "Local encrypted persistence using SQLCipher with secure key storage.", "Optional Google Drive backup/restore and controlled sharing/QR workflows.", "Release hardening, R8 shrinking, resource shrinking, and size analysis."])
    doc.add_heading("4.2 Out of scope", level=2)
    add_bullets(doc, ["Clinical diagnosis, treatment recommendations, or emergency medical decision-making.", "Replacing a hospital information system or electronic medical record system.", "Server-side end-to-end encryption for Google Drive/Firebase content beyond provider controls.", "Automatic synchronization of every record without user/account consent.", "Recovery of an encrypted database when the device secure-storage key has been permanently destroyed."])
    doc.add_heading("5. Proposed solution", level=1)
    doc.add_heading("5.1 User journey", level=2)
    add_numbered(doc, ["User selects a language and completes sign-in/onboarding.", "App creates or imports the first family profile.", "App generates a random SQLCipher key and stores it in secure platform storage.", "App opens the encrypted local database and presents Home.", "User selects a family member and records BP, sugar, weight, medicine, or report data.", "User receives local reminders and reviews history.", "User optionally backs up profiles or shares selected information."])
    doc.add_heading("5.2 Security design", level=2)
    add_table(doc, ["Control", "Business value"], [("SQLCipher database", "Reduces exposure if a database file is copied from device storage."), ("Random per-install key", "Prevents a universal application password from unlocking every installation."), ("Android Keystore / iOS Keychain via secure storage", "Uses platform-protected storage for the database key."), ("Fail-closed key handling", "Avoids silently opening an empty or plaintext database when authentication fails."), ("R8 and resource shrinking", "Reduces attack surface and release size by removing unused code/resources."), ("No sensitive logging", "Reduces accidental exposure through debug logs and crash reports.")], [2.3, 4.5])
    add_callout(doc, "Important limitation", "Database encryption is an at-rest control. It does not prevent a user with an unlocked device from viewing records in the app, taking screenshots, exporting selected data, or sharing information intentionally.")
    doc.add_heading("6. Business rules", level=1)
    add_bullets(doc, ["Every health record, medicine, and report must be associated with one family member.", "The selected member is the default scope for Home, Health, Reports, and Medicines.", "Only active medicines participate in scheduled reminders.", "A report may be stored locally before optional remote backup.", "A user must explicitly initiate profile backup, restore, or sharing.", "The app must not claim that a measurement is a diagnosis.", "Changing or deleting the secure database key is a destructive recovery event and requires explicit product handling."])
    doc.add_heading("7. Delivery plan and acceptance", level=1)
    add_table(doc, ["Phase", "Deliverables", "Exit criteria"], [("1. Foundation", "Dependencies, secure key storage, SQLCipher open path", "Fresh install creates and reads encrypted DB."), ("2. Migration", "Legacy plaintext snapshot/import/delete flow", "Seeded v2 DB migrates; backup removed only after verification."), ("3. Application QA", "Feature regression and localization checks", "Existing tests pass; core flows work offline."), ("4. Security QA", "Wrong-key, key deletion, file inspection, logs review", "No plaintext DB or key leakage in tested scenarios."), ("5. Release QA", "R8 build, APK/AAB, device matrix", "Release artifact installs and opens on supported Android versions."), ("6. Documentation", "SRS, BRD, runbook, support notes", "Stakeholders can approve scope and operate the release.")], [1.2, 3.1, 2.5])
    doc.add_heading("8. Risks, assumptions, and dependencies", level=1)
    add_table(doc, ["Item", "Response"], [("Flutter toolchain is older than latest SQLCipher package", "Pin sqflite_sqlcipher 3.2.0 for current Flutter 3.22/Dart 3.4; upgrade during a planned toolchain update."), ("iOS FMDB conflict", "Validate CocoaPods integration on a real iOS build; use the package-recommended override if a dependency links the normal FMDB pod."), ("Migration interruption", "Retain and verify a temporary backup until encrypted import succeeds; test process death and low storage."), ("Lost secure-storage key", "Treat as unrecoverable local encryption loss unless the user has a separate application-level backup/export."), ("Native dependency size", "Re-run APK/AAB size analysis after adding SQLCipher and keep only required ABIs for each distribution channel."), ("Cloud backup privacy", "Document that cloud backup and Firebase storage have separate access-control and retention policies.")], [2.0, 4.8])
    doc.add_heading("9. Approval", level=1)
    doc.add_paragraph("Product owner: ____________________    Date: ____________")
    doc.add_paragraph("Engineering lead: __________________    Date: ____________")
    doc.add_paragraph("Security / privacy review: ____________    Date: ____________")
    doc.save(OUT / "Gramin_Swasthya_BRD.docx")


if __name__ == "__main__":
    make_srs()
    make_brd()
    print(OUT / "Gramin_Swasthya_SRS.docx")
    print(OUT / "Gramin_Swasthya_BRD.docx")
