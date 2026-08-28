import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget for the state of the chezmoi dotfiles.
//
// Modelled on the first-party omarchy.system-update widget: invisible while
// there is nothing to do, so it costs no bar space on a machine that is in
// step. The counts come from `dotfiles-status`, which is also what the Omarchy
// menu's Dotfiles submenu and dotfiles-sync read, so all three always agree.
BarWidget {
  id: root
  moduleName: "carson.dotfiles"

  // Straight from dotfiles-status; `loaded` distinguishes "all zero" from
  // "not asked yet", which is what keeps the widget hidden on first paint.
  property int applyNeeded: 0
  property int localEdits: 0
  property int behind: 0
  property int ahead: 0
  property int uncommitted: 0
  property bool ok: true
  property bool loaded: false
  // [{path, status, added, removed, binary}] -- what an apply would change.
  property var files: []

  readonly property string glyph: "󰊢"

  // localEdits means a target changed after chezmoi last wrote it -- an Omarchy
  // migration, `omarchy refresh`, or a hand edit. chezmoi will not overwrite
  // such a file without being told to, so this is the one state that needs a
  // decision rather than just a command, and the only one that goes urgent.
  readonly property bool needsDecision: localEdits > 0
  readonly property bool hasWork: applyNeeded > 0 || localEdits > 0 || behind > 0
                                  || ahead > 0 || uncommitted > 0

  readonly property string badge: {
    if (localEdits > 0) return "!" + localEdits
    if (behind > 0) return "↓" + behind
    if (ahead > 0) return "↑" + ahead
    if (uncommitted > 0) return "↑" + uncommitted
    if (applyNeeded > 0) return "•" + applyNeeded
    return ""
  }

  // A vertical bar has no room for the glyph and the badge side by side.
  readonly property string label: {
    if (badge === "") return glyph
    return root.vertical ? badge : glyph + "  " + badge
  }

  // How many files to name before collapsing the rest into a count.
  readonly property int fileLimit: Math.max(0, root.setting("tooltipFiles", 8))

  function describeFile(f) {
    var change = f.binary ? "(binary)"
      : "+" + (f.added || 0) + " -" + (f.removed || 0)
    // Column 1 of `chezmoi status`: the target changed after chezmoi last
    // wrote it. Worth calling out inline, since those are the ones an apply
    // will refuse to overwrite.
    var mark = (f.status && f.status.charAt(0) !== " ") ? "! " : "  "
    return mark + f.path + "   " + change
  }

  readonly property string tooltip: {
    var lines = []
    if (localEdits > 0) lines.push(localEdits + " changed outside chezmoi — needs a decision")
    if (applyNeeded > 0) lines.push(applyNeeded + " pending apply")
    if (behind > 0) lines.push(behind + " commit(s) behind")
    if (ahead > 0) lines.push(ahead + " commit(s) ahead")
    if (uncommitted > 0) lines.push(uncommitted + " uncommitted change(s)")
    if (!ok) lines.push("(status may be stale — could not reach the remote)")
    if (lines.length === 0) lines.push("Dotfiles are in step")

    var list = root.files || []
    if (list.length > 0 && root.fileLimit > 0) {
      lines.push("")
      for (var i = 0; i < list.length && i < root.fileLimit; i++)
        lines.push(root.describeFile(list[i]))
      if (list.length > root.fileLimit)
        lines.push("  … and " + (list.length - root.fileLimit) + " more")
    }

    lines.push("")
    lines.push("Left: open sync menu · Right: pull & apply · Middle: refresh")
    return lines.join("\n")
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function apply(output) {
    try {
      var d = JSON.parse(String(output || "").trim())
      root.applyNeeded = d.applyNeeded || 0
      root.localEdits = d.localEdits || 0
      root.behind = d.behind || 0
      root.ahead = d.ahead || 0
      root.uncommitted = d.uncommitted || 0
      root.ok = d.ok === true
      root.files = Array.isArray(d.files) ? d.files : []
      root.loaded = true
    } catch (e) {
      console.warn("carson.dotfiles: could not parse dotfiles-status output:", e)
      root.ok = false
    }
  }

  function openSync() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation dotfiles-sync")
  }

  // Deliberately in a floating terminal rather than a silent Process: a pull can
  // stop on a merge conflict or an out-of-band edit, and swallowing that would
  // leave the bar quietly wrong.
  function pullAndApply() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation dotfiles-sync pull")
    settleTimer.restart()
  }

  visible: loaded && hasWork
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "carson.dotfiles"

    function refresh(): string {
      root.broadcast("refresh")
      return "ok"
    }
  }

  Process {
    id: statusProc
    command: ["dotfiles-status", "--fetch"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("carson.dotfiles:", text.trim())
    }
  }

  Timer {
    id: pollTimer
    interval: Math.max(60, root.setting("refreshIntervalSec", 1800)) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Give a pull started above time to finish before re-reading the counts.
  Timer {
    id: settleTimer
    interval: 20000
    repeat: false
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    active: root.needsDecision
    tooltipText: root.tooltip
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) root.pullAndApply()
      else if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.openSync()
    }
  }
}
