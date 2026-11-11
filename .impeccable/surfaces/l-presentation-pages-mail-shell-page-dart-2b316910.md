---
version: 1
slug: "l-presentation-pages-mail-shell-page-dart-2b316910"
primary_target: "lib/features/mail/presentation/pages/mail_shell_page.dart"
related_targets: ["lib/features/mail/presentation/pages/unified_inbox_page.dart","lib/features/mail/presentation/pages/email_detail_page.dart","lib/features/mail/presentation/pages/compose_email_page.dart","lib/app/app.dart"]
---

# 邮箱主界面

Mode: Operate; reading detail also serves Read. Xiaomi 15 first, adaptive layouts on every supported platform. User selected blue-flow in decision 979707b9 on 2026-11-10, code-led. Approved first viewport: `docs/design/blue-flow-sketch.html`. Synthetic examples never enter production data.

## Direction contract

THESIS: 克莱因蓝明确导航，稳定的实心阅读表面承托邮件；让选择与展开连续流动，避免重复标题与默认组件堆叠。

OWN-WORLD: Digital Klein blue #002FA7, ivory #F7F7F2, white #FFFFFF, ink #17213B. Opaque navy night surfaces with accessible lighter blue accents. System Chinese typography, aligned sender/subject/time, restrained account marks, generous curved container joins. No decorative blur or translucent surfaces.

STORY: 一眼识别当前邮箱与未读状态，扫描发件人和主题，直接进入阅读、复制验证码或写信。手机用可滚动账户侧栏，电脑保留多栏。

FIRST VIEWPORT: Compact blue toolbar with menu, name, notifications and search; large current inbox title/scope below. White opaque list joins with a 28–30dp upper curve. All/unread pill and sync sit above 4–5 comfortably spaced message rows. Blue compose action is reachable at lower right. Exact count only when truthful. Signature “触点扩散”: full-page navigation expands an opaque organic boundary from the recent tap (420ms in, 280ms out); page text stays stationary. The existing interruptible filter spring and sidebar expansion remain. Native interactive-back gestures retain platform feedback. Reduced motion resolves immediately and idle has no decorative tickers.

FORM: Sixth grounded candidate, music tracklisting translated only into type, palette, density and one signature move; controls and state remain native mail. Code-led, approved blue-flow sketch. SEED REFERENCE seed:8b2e2eae7eb44151. Carry clarity and stable alignment from declined challengers; no borrowed costumes.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Boundaries

Keep all existing operations, semantics, stable widget keys where possible, draft guards, lazy lists, safe HTML and non-hybrid Android composition. Keep system theme, 48dp touch targets, large text, keyboard and native return gestures. No protocol/database/auth/background work. No new dependencies, fonts or images required. Related screens share the theme and controls; detail/compose/search/account/settings retain content-first layout.

## Motion refinement — 2026-11-10

User rejected the incumbent native flip/fade after implementation and explicitly requested liquid-like full-screen spreading for every button-triggered page change. Keep the accepted visual world. Focal: opaque point-origin reveal, not glass. Continuity: reverse the same geometry on ordinary pop; cancel native interactive gestures safely. Feedback: no delayed business actions, text remains stationary. Budget: one finite route animation with a 16-segment clip, no custom shader, blur, extra controller, or idle loop; bypass clipping at rest/reduced motion. All full-screen Material routes inherit globally; dialogs and system-owned screens retain their own presentation.
