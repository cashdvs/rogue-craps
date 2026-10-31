## Bug-report text (design/strings_v1.md "Bug report (PR #221)" rows).
## TEXT holds the strings_v1 cells verbatim, keyed by their strings_v1 id,
## with {placeholders}, like GoalStrings. BugReport reads them by id.
class_name BugReportStrings
extends RefCounted

## strings_v1 id -> text (copied verbatim; check_strings.py owns the source).
const TEXT: Dictionary[String, String] = {
	"bug_report_button": "REPORT A BUG",
	"bug_report_what": "What happened:",
	"bug_report_saved": "Screenshot saved, attach it: {path}",
	"bug_report_no_mail": "No mail app: report copied, email it to tinyanvilgames@mail.grokbot.com",
}


## The raw text for strings_v1 id [param id] ("" if unknown).
static func get_text(id: String) -> String:
	return TEXT.get(id, "")
