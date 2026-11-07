# Native iOS controls with paper content

All five apps share the same paper tile. Navigation bars use UIKit's standard glossy, tinted rendering; no cloth background or custom navigation image remains. Native back/edit/add controls, switches, keyboards and tab bars keep platform behavior.

Meals uses native rounded grouped cells and UIKit section headers and footers. Its printed macro rings remain informational. Sets and Habits use standard table separators and native blue selection, with paper behind their entries. Claude uses standard bar buttons, a native navigation title and a rounded UIKit Send/Stop button. Cards retains its index-card content but uses native rounded Again/Hard/Good/Easy rating buttons and a standard navigation bar.

Paper is content, not a replacement control skin. Existing data, targets, schedules, integrations and storage schemas are unchanged. Update the identical JRMaterials.h copies in all five repositories together.
