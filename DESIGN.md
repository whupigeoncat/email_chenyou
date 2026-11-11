---
name: 本地邮箱
description: 以克莱因蓝导航、不透明阅读表面、触点扩散转场与弹性选择控件构成的本地邮箱视觉系统。
colors:
  klein-blue: "#002FA7"
  klein-blue-deep: "#00164D"
  klein-blue-soft: "#E4EBFF"
  blue-container-night: "#243758"
  on-blue-night: "#F0F4FF"
  blue-night-accent: "#A9C3FF"
  blue-wash: "#B8CBFF"
  ivory: "#F7F7F2"
  paper-white: "#FFFFFF"
  ink: "#17213B"
  slate-ink: "#15213A"
  ink-muted: "#5A6478"
  navy-night: "#0B1328"
  navy-panel-night: "#0F1A31"
  navy-raised-night: "#14213B"
  navy-menu-night: "#192845"
  navy-snackbar-night: "#1F3050"
  text-night: "#E9EDF7"
  text-night-muted: "#B2BDD4"
  field-day: "#F4F5F1"
  field-night: "#111D35"
  track-day: "#E9ECF3"
  track-night: "#1B2A45"
  avatar-day: "#E9EEF9"
  avatar-night: "#1C2D4E"
  hairline-day: "#E3E4DF"
  hairline-night: "#2A3A56"
  success-day: "#1D6B4A"
  success-night: "#7EDDB2"
  warning-day: "#8A5300"
  warning-night: "#FFC46B"
  danger-day: "#B3261E"
  danger-night: "#FFB4AB"
typography:
  display:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "36px"
    fontWeight: 700
    lineHeight: 1.16
    letterSpacing: "-0.8px"
  headline:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.22
    letterSpacing: "-0.5px"
  headline-small:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.33
    letterSpacing: "-0.3px"
  title:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.27
    letterSpacing: "-0.2px"
  title-small:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: "0.15px"
  body:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "0.25px"
  body-large:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "0.5px"
  body-small:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "0.4px"
  label:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.43
    letterSpacing: "0.1px"
  label-strong:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: 1.43
    letterSpacing: "0.1px"
  label-small:
    fontFamily: "system-ui, -apple-system, sans-serif"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: 1.45
    letterSpacing: "0.5px"
rounded:
  control: "14px"
  card: "18px"
  compose: "22px"
  dialog: "24px"
  sheet: "28px"
  panel: "28px"
  pill: "999px"
spacing:
  hairline: "1px"
  tight: "4px"
  compact: "8px"
  inline: "10px"
  row: "12px"
  field: "14px"
  page: "16px"
  action: "18px"
  section: "20px"
  block: "24px"
  sheet: "28px"
  empty: "32px"
components:
  button-filled:
    backgroundColor: "{colors.klein-blue}"
    textColor: "{colors.paper-white}"
    typography: "{typography.label-strong}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
    height: "48px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.klein-blue}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "12px 16px"
    height: "48px"
  button-text:
    textColor: "{colors.klein-blue}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "10px 14px"
    height: "48px"
  compose-action:
    backgroundColor: "{colors.klein-blue}"
    textColor: "{colors.paper-white}"
    typography: "{typography.label}"
    rounded: "{rounded.compose}"
  field:
    backgroundColor: "{colors.field-day}"
    textColor: "{colors.ink}"
    typography: "{typography.body-large}"
    rounded: "{rounded.control}"
    padding: "14px"
  filter-switch:
    backgroundColor: "{colors.track-day}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "4px"
    height: "56px"
  filter-switch-selected:
    backgroundColor: "{colors.klein-blue}"
    textColor: "{colors.paper-white}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
  nav-item:
    textColor: "{colors.ink}"
    typography: "{typography.body-large}"
    rounded: "{rounded.control}"
    padding: "10px 16px"
  nav-item-selected:
    backgroundColor: "{colors.klein-blue-soft}"
    textColor: "{colors.klein-blue-deep}"
    rounded: "{rounded.control}"
  card:
    backgroundColor: "{colors.paper-white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    padding: "16px"
  card-code:
    backgroundColor: "{colors.avatar-day}"
    textColor: "{colors.slate-ink}"
    rounded: "{rounded.card}"
    padding: "10px 8px 10px 14px"
---

# Design System: 本地邮箱

## Overview

**Creative North Star: "The Klein Current"（克莱因流）**

本地邮箱的视觉系统是一条**稳定电流**：导航与选择由克莱因蓝承担，阅读表面保持不透明的安静，交互时，页面从触点扩散，筛选胶囊连续移动；静止时不运行装饰动画。页面不靠装饰、模糊或透明度表达“流动”，而靠颜色占比、连续曲率和一个可以被中途改意的弹性位移，让操作读起来像一股不间断的水流。

系统的密度是中等偏舒适的：邮件行至少 110dp 高，行距足以扫读发件人、主题与时间；导航、控件与容器共享同一套圆角家族，避免相邻表面出现互不相干的曲率。层次靠实心表面之间的明度差与 1dp 发丝线建立，卡片与列表默认平铺；模态面板沿用 Material 原生抬升，系统没有自定义或装饰性阴影。

这套世界同时服务手机与电脑：手机主界面是蓝色头部加一张上圆角的白色阅读面板；其他阅读与设置页面仍使用当前主题的表面色顶栏。电脑是同一语言下的两栏或三栏。栏数改变，配色、字体层级、圆角与控制手感不变。

**Key Characteristics:**
- 克莱因蓝只做导航、选择与主操作；大面积留给象牙白/纸白或深夜蓝。
- 所有承托表面不透明；流动感来自运动与曲率，不来自模糊或半透明。
- 层级靠字重、字距、明度差与发丝线，不靠多字体家族。
- 控件圆角来自同一家族（14/18/22/24/28），胶囊是唯一的全圆角。
- 页面导航从触点以不透明轮廓扩散至全屏；筛选胶囊保留弹性位移，两者都可被中断并响应系统“减少动画”。

## Colors

一套“数字克莱因蓝 + 纸面”的两极配色：白天是蓝、象牙白与墨蓝的三段式，夜晚保留同一块蓝，只把承托表面换成不透明的深海蓝。

### Primary

- **Klein Blue**（`colors.klein-blue`）：品牌与交互的绝对主色。手机头部的整块蓝、FAB、筛选胶囊、未读圆点、焦点描边与选中态容器都从它派生。两种主题都使用同一块蓝，不因夜间模式而调淡导航。
- **Klein Blue Deep**（`colors.klein-blue-deep`）：落在浅蓝容器上的文字色，如白天选中导航项的深蓝文字；也是夜间主色底上的文字色。
- **Klein Blue Soft**（`colors.klein-blue-soft`）：白天选中导航项的实心底、浅色主题的 `primaryContainer`。它只出现在“当前所在”或“被选中”的容器上，不做装饰性铺底。
- **Blue Container Night**（`colors.blue-container-night`）：夜间 `secondaryContainer`，用于夜色下的彩色容器（如验证码卡片）。夜间选中导航项则直接使用 Klein Blue 实底，文字改用 **On Blue Night**（`colors.on-blue-night`）。
- **Blue Night Accent**（`colors.blue-night-accent`）：夜间主题的 `primary`。链接、进度、焦点与小面积强调在深海军蓝表面上改用这块更亮的蓝。
- **Blue Wash**（`colors.blue-wash`）：夜间头像字色与深色 Snackbar 上的操作文字；只在深底需要“蓝但可读”时出现。

### Neutral

- **Ivory**（`colors.ivory`）：白天页面底色（`surface`）。导航栏与列表之间的呼吸由它承担，不靠阴影。
- **Paper White**（`colors.paper-white`）：白天阅读面板、卡片、对话框与抽屉的实心底。手机列表以它整块上升，形成上半蓝、下半白的清晰分界。
- **Ink**（`colors.ink`）：白天主文字与深色 Snackbar 底。标题、正文、图标默认落在它上面。
- **Slate Ink**（`colors.slate-ink`）：验证码卡片等浅蓝容器上的正文色，比主墨色更贴近蓝调。
- **Ink Muted**（`colors.ink-muted`）：白天次级文字（范围、摘要、时间、账户名）与未选中标签。
- **Navy Night**（`colors.navy-night`）：夜间 `surface`。夜间脚手架不是黑色，而是偏蓝的深底。
- **Navy Panel Night**（`colors.navy-panel-night`）：夜间列表、卡片、侧栏的承托面；比脚手架亮一级，用明度差代替投影。
- **Navy Raised Night**（`colors.navy-raised-night`）：夜间对话框与底部面板的抬升面。
- **Navy Menu Night**（`colors.navy-menu-night`）：夜间弹出菜单的底色，比对话框再高一档，保证菜单浮在对话框之上时仍能分辨。
- **Navy Snackbar Night**（`colors.navy-snackbar-night`）：夜间浮动 Snackbar 的底色；白天对应深墨色。
- **Text Night** / **Text Night Muted**（`colors.text-night`、`colors.text-night-muted`）：夜间的正文与次级文字。
- **Field Day / Field Night**（`colors.field-day`、`colors.field-night`）：输入框实心填充；比页面底色略深或略亮，靠填充而非白底描边区分可输入区。
- **Track Day / Track Night**（`colors.track-day`、`colors.track-night`）：筛选轨道与滑轨的底色。轨道始终比承托面板暗一档，让胶囊的蓝色跳出来。
- **Avatar Day / Avatar Night**（`colors.avatar-day`、`colors.avatar-night`）：发件人头像底。圆角方块，不用照片；白天的浅蓝与 `secondaryContainer` 同值，夜间头像更深一档。
- **Hairline Day / Hairline Night**（`colors.hairline-day`、`colors.hairline-night`）：1dp 分隔线与卡片描边。它是结构线，不是装饰线，永远保持 1dp。
- **Success / Warning / Danger**（`colors.success-day`、`colors.success-night` 等三组）：仅用于连接状态、星标与错误。两套主题各有一组，保证深底上仍然可读；它们是状态色，不是第二品牌色。

### Named Rules

**The Klein Constant Rule.** 克莱因蓝是导航与选择的常量。夜间模式替换表面、文字和小面积强调，不替换这块蓝；任何新界面都不得引入第二个“主色”与它竞争。手机主界面的蓝色头部是允许的大面积用色——占比服从页面角色，而不是一条全局的“少用蓝”配额。

**The Opaque Bearing Rule.** 承托邮件的表面必须不透明。不要用毛玻璃、背景模糊、半透明蒙层来表现流动或层级；Material 标准的状态层与过渡透明度不受此限。

## Typography

**Display Font:** 系统 UI 字体（由各操作系统解析，CJK 走平台原生中文回退；项目不捆绑文本字体）
**Body Font:** 同上
**Label Font:** 同上

**Icons:** Flutter 自带的 MaterialIcons，随框架提供，不是额外资源或新依赖。

**Character:** 一套字、靠字重和字距建立层级。标题收紧字距并加粗，正文保持中性行高，元信息缩小并使用等宽数字对齐时间列；中文与拉丁共用同一行高节奏，不做混排装饰。

> 单位说明：frontmatter 与本文中的 `px` 承载 Flutter 的逻辑单位——字号对应 sp，尺寸/间距对应 dp，均随系统字体缩放与像素密度变化。

### Hierarchy

- **Display**（w700，Material 3 `displaySmall` 36sp，行高 1.16，字距 −0.8）：手机头部的当前收件箱名。整屏只出现一次，不用于卡片标题。
- **Headline**（w700，`headlineMedium` 28sp，行高 1.22，字距 −0.5）：无蓝色头部的内嵌页面标题。
- **Headline Small**（w700，`headlineSmall` 24sp，字距 −0.3）：阅读页邮件主题。
- **Title**（w700，`titleLarge` 22sp，字距 −0.2）：对话框标题、验证码值、紧凑头部标题。
- **Title Small**（w600，`titleMedium` 16sp）：头像首字、紧凑头部标题、空状态标题与邮件主题（未读时提到 w700）。
- **Body Large**（w400，`bodyLarge` 16sp，行高 1.45）：列表主行、阅读页发件人行与输入框文字。
- **Body**（w400，`bodyMedium` 14sp，行高 1.45）：正文、范围行与辅助文字。
- **Body Small**（w400，`bodySmall` 12sp，行高 1.4）：摘要、日期、账户元信息、辅助说明。
- **Label**（w600，`labelLarge` 14sp；主按钮 w700）：按钮、筛选段、胶囊文字与发件人行。
- **Label Small**（w500，`labelSmall` 11sp，等宽数字）：邮件行右上时间与连接状态。时间列使用 tabular figures，数字变化不推动布局。

### Named Rules

**The One Family Rule.** 只用系统文本字体家族。层级由字重、字号、字距与颜色完成，不新增展示字体或额外字体依赖；图标沿用框架自带的 MaterialIcons，需要“更强调”时先加字重或提高对比，而不是换字体。

**The Still Label Rule.** 选择态切换时，标签文字的位置、字号与行高不变，只换颜色。运动属于胶囊，不属于文字。

## Layout

单列手机 → 两栏紧凑桌面 → 三栏宽桌面的同一套栅格。

- **断点**：宽度 `< 960` 为手机/单栏（抽屉 + 列表 + 推入详情）；`≥ 960` 为侧栏 + 列表；`≥ 1200` 再分出阅读栏。断点只改变栏数与容器宽度，不改变配色与控件尺寸。
- **栏宽**：侧栏为宽度的 22%，夹在 250–300 之间；阅读栏为宽度的 34%，夹在 340–480 之间。列表始终吃掉剩余宽度。
- **手机结构**：蓝色头部（状态栏安全区 + 52dp 工具栏 + 标题/范围）下方紧接一张 `panelTop` 28dp 上圆角的实心阅读面板，用弧线把蓝面与白面切开。头部在高度 `< 520` 时压成单行 52dp，把范围行交给抽屉。
- **页面内边距**：列表页 20dp 起始；筛选条 20/6/10/8；阅读页 16/12/16/28，正文最大宽度 820dp 并居中；空状态 32dp。
- **行密度**：邮件行最小高度 110dp，内边距 20/12/8/12，头像 40dp 与内容间距 12dp；发件人、主题、摘要、账户行依次堆叠，时间与星标固定在右列；右列宽度取 48dp 与“时间宽度 + 6dp”的较大值，随系统字号扩张。
- **触控**：所有可点目标的实际响应区域不小于 48dp；图标按钮、分段控件与胶囊段都按 48dp 设计，视觉尺寸可以更小。
- **列表与滚动的底边**：列表底部内边距为系统底部安全区 + 8dp，悬浮写信按钮不遮挡最后一行。
- **侧栏收缩**：高度 `< 440` 或字体缩放后 14sp 实际超过 18dp 时，侧栏整体变成一个可滚动列表（头部、账户、页脚一起滚），避免固定页脚挤压内容。

## Elevation & Depth

这是一个**默认平铺、模态沿用原生抬升**的系统。卡片与 AppBar 明确设为 elevation 0，列表与侧栏不叠加 elevation，`surfaceTintColor` 透明；这些静止表面的深度由不透明色阶（象牙白 → 纸白 → 浅蓝容器；夜间 `navy-night` → `navy-panel-night` → `navy-raised-night`）和 1dp 发丝线承担。对话框、抽屉、弹出菜单、底部面板与 Snackbar 不覆盖 elevation，继续使用 Material 原生层级；它们的存在本身就需要浮在内容之上。

写信按钮显式设为 elevation 3、按下 2，确保主操作在滚动内容之上始终可点。Snackbar 采用浮动样式，用深墨色/夜间 `navy-snackbar-night` 与当前页面区分。系统没有自定义投影、彩色光晕或装饰性阴影词汇；这些表面上的 Material 原生阴影是平台行为，不是设计 token。

### Named Rules

**The Native-Lift Rule.** 静止的卡片、AppBar、列表与侧栏保持 elevation 0，需要分层时先换表面色或加发丝线。对话框、菜单、抽屉、底部面板与 Snackbar 沿用 Material 原生 elevation；不要为它们手写阴影，也不要把写信按钮的 elevation 复制到普通表面。

## Shapes

一个圆角家族贯穿所有控件：小控件 14dp、卡片 18dp、写信按钮 22dp、对话框 24dp、面板与底部面板 28dp。头像复用 14dp，与输入框、按钮、导航选中块同族；抽屉只圆右侧 24dp，保持“从边缘滑出”的方向感。筛选轨道与胶囊是唯一的全圆角（999dp 胶囊/体育场形），因为它的语义就是“一个可以滑动的药丸”，不是普通容器。

边框只有一种：1dp 发丝线，颜色取当前主题的 `outlineVariant`。卡片与列表分隔线都用它；分隔线在邮件行从 72dp 缩进、右端留 20dp，让头像列成为一条安静的竖轴。没有粗描边、没有双线、没有硬偏移阴影。

### Named Rules

**The One Curvature Rule.** 同一屏内的容器只从 14/18/22/24/28 中取用，并保持“越小越方、越大越圆”的顺序。不要为单个组件发明 8dp 或 12dp 的孤立圆角；胶囊只属于选择控件。

## Components

控件全部是原生 Material 组件 + 主题覆盖，保留原生语义、焦点顺序、键盘操作与系统返回手势。以下描述的是主题化后的稳定外观。

### Buttons

- **Shape:** 圆角 14dp（`rounded.control`），最小 48×48dp。
- **Primary（Filled）:** 日间克莱因蓝实底、纸白文字；夜间使用当前主题的亮蓝 primary 与深色 onPrimary、`label` 字重 700，内边距 12/18（上下/左右）。用于“添加邮箱账户”等确认性动作。
- **Secondary（Outlined）:** 透明底、1dp 发丝描边、主色文字、字重 600，内边距 12/16。回复/全部回复/转发三连用它，并排时靠 `Wrap` 与 6dp 间距换行。
- **Text:** 无底无边、主色文字、字重 600，内边距 10/14。用于“加载更早邮件”“加载内嵌图片”等低权重动作。
- **Hover / Focus:** 按钮不覆盖状态过渡时长，沿用 Material 原生状态层与焦点高亮；按钮本身不加描边、不改变尺寸、不位移。项目自定义的 140ms 只用于筛选标签颜色与账户展开箭头。
- **Compose（Extended FAB）:** 克莱因蓝实底、纸白图标与“写邮件”、圆角 22dp、elevation 3。手机右下角常驻；无账户时隐藏，不用禁用态占位。

夜间普通 Filled / Outlined / Text 按钮使用当前主题的 primary 角色；FAB 与筛选胶囊仍固定品牌蓝。frontmatter 组件默认值和 sidecar HTML 示例展示日间外观。

### Inputs / Fields

- **Style:** 实心填充（`field-day`/`field-night`），1dp 发丝描边，圆角 14dp，内边距 14dp；输入文字为 `bodyLarge` 16sp，标签与提示文字使用次级文字色。
- **Focus:** 描边换成克莱因蓝并加粗到 1.6dp；不使用外发光。错误态同样形状，描边换 `error`，聚焦错误态 1.6dp。
- **Disabled:** 沿用 Material 原生降透明处理，不另造灰底。
- **Textarea / 写信字段:** 复用同一装饰与圆角，只改变行数与最小高度，不新增第二种输入外观。

### Selection Pill（签名控件）

- **Track:** 胶囊轨道，底色为 `track-day`/`track-night`，内边距 4dp；每段最小高度 48dp，轨道总高 56dp。轨道宽度按最长标签测量后收紧，空间不足时优先压缩段内水平留白（最小 8dp）。
- **Pill:** 单个克莱因蓝胶囊在段间移动，圆角 999dp；文字在胶囊之上，选中为纸白、未选中为次级文字色。
- **Motion:** 弹簧 420ms、bounce 0.12，从当前速度重新指向新目标，可在中途改意；只有胶囊移动，标签不动。系统开启“减少动画”时直接落位，不保留 ticker 或定时器。
- **Semantics:** 容器有组标签，每段是 button + selected 的原生语义；当前段不重复触发回调。
- **扩展边界:** 目前只用于“全部/未读”两段；未来更多标签时保持同一测量与压缩规则，不改成等宽硬切。

### Page Transitions

应用内所有 `MaterialPageRoute` 共用一套触点扩散，普通点按不再使用横向翻页、缩放或淡入。新页面的文字和布局固定，由 16 段平滑三次曲线组成的轮廓逐步露出，承托底色始终不透明。进入 420ms、普通返回 280ms，使用同一个 `easeInOutCubic` 进度函数，因此中途反向返回不会跳边。

根部监听主指针并由稳定的导航观察器把最近触点记录到对应路由；一次使用后清除，拖动、取消、键盘操作或超过 700ms 的旧点不复用。无触点时从中央扩散。触点按导航区域归一化，尺寸改变后仍合理；返回沿原进入点收拢。没有独立动画控制器或定时器，页面完成后关闭裁切，保持 HTML WebView 状态。

原生返回手势识别器始终保留：Android 预测性返回及 iOS/macOS 交互返回进行期间使用系统反馈并停用扩散裁切，取消手势后保持原页面；普通进入/返回时将原生滑动动画固定在完成状态，由扩散轮廓呈现。系统“减少动画”下直接显示完整新页面。草稿、发送中和附件处理的返回保护不变；对话框、抽屉、系统授权或文件选择不属于全屏页面转场。

### Navigation

- **Sidebar（≥960dp）:** 页面底色表面，列表项 14dp 圆角、行高由 ListTile 原生密度决定（命中区域不小于 48dp）、内边距 10/16；选中项用浅蓝实底 + 深蓝文字，不使用左侧色条。账户行以 12dp 圆点账户色 + 邮箱地址 + 11sp 连接状态组成，右侧是展开箭头。
- **Mobile Drawer:** 单列可滚动，头部“邮箱”与添加/收起图标固定节奏；账户展开用 220ms 的尺寸+淡入，收起用退出曲线，箭头旋转 140ms。抽屉圆右侧 24dp。
- **App Bar:** `surface` 表面色底、`surfaceTintColor` 透明、elevation 0、无阴影、标题左对齐、字重 700；图标按钮 48dp 并带 tooltip。只有邮箱主界面（Mail Shell）的手机头部改成整块克莱因蓝，前景为纸白/浅蓝，状态栏图标强制浅色；阅读、搜索、写信与设置等页面保留表面色顶栏。
- **Scope Row:** 头部标题下的“所有邮箱 / 具体邮箱”是最小 48dp 高的可点行，右端一个 18dp 方向箭头，点击打开抽屉切换范围。

### Cards / Containers

- **Corner Style:** 18dp（`rounded.card`）。
- **Background:** 白天纸白；夜间 `navy-panel-night`。验证码卡片使用浅蓝容器（白天与头像底同一块 `avatar-day`，夜间换成 `blue-container-night`）+ 深蓝文字，是唯一有彩色底的卡片。
- **Border:** 1dp 发丝线，`Clip.antiAlias` 裁切内部内容。
- **Internal Padding:** 16dp；验证码卡片 14/10/8/10。附件行使用紧凑 ListTile，底部间距 6dp。
- **Shadow Strategy:** 卡片 elevation 0，无自定义阴影；对话框与底部面板沿用 Material 原生抬升。见 Elevation & Depth。

### Mail Rows

- **Character:** 一行邮件是一张没有卡片外框的“纸面条目”，靠对齐和字重而不是边框区分。
- **Structure:** 40dp 圆角头像（首字，浅蓝底、主色字）→ 发件人（未读 w700 / 已读 w500）→ 主题（未读 w700 / 已读 w500，`onSurface`）→ 单行摘要 → 账户色点 + 账户地址 + 附件回形针；右上角时间（11sp、等宽数字、次级色）与星标（21dp，星标时用 warning 色）。
- **Unread:** 未读时在发件人前显示 6dp 克莱因蓝圆点；标为已读后圆点消失、发件人转为次级色、主题回到 w500 的常规墨色。列表行原地更新，不做删除动画。
- **Swipe:** 右向左滑动露出浅蓝底 + “标为已读”图标，动作后行原地更新（不删除），避免列表跳动。

## Do's and Don'ts

### Do:

- **Do** 用 `colors.klein-blue` 承担导航、选择、未读标记和主操作；其余表面保持纸白/象牙白或深夜蓝。
- **Do** 让手机阅读面板保持 28dp 上圆角与实心底色，用弧线切开蓝色头部，不用投影或半透明过渡。
- **Do** 用字重、字距、字色与发丝线建立层级；标题收紧字距（−0.2 至 −0.8），正文保持 1.4–1.45 行高。
- **Do** 让时间列使用等宽数字，并让右列随系统字号增宽，保证大字体下最后一位不被裁切。
- **Do** 所有可点目标保持至少 48dp 的响应区域；图标按钮保留 tooltip，并保留原生焦点、键盘与系统返回手势。
- **Do** 选择态只移动胶囊，文字位置与字号保持不变；开启减少动画时即时落位。
- **Do** 需要分层时先换不透明表面色或加 1dp 发丝线；只有模态与悬浮动作使用原生抬升。

### Don't:

- **Don't** 使用毛玻璃、背景模糊、半透明面板或渐变来表现“流动”；流动由运动、曲率和蓝色占比表达。
- **Don't** 捆绑或声明自有的展示字体，也不要新增图标字体依赖；文本走系统字体，图标使用框架自带的 MaterialIcons。
- **Don't** 为卡片、列表与侧栏手写投影，也不要把写信按钮的 elevation 复制到普通表面；对话框、菜单、抽屉、底部面板与 Snackbar 的原生抬升不在此限。
- **Don't** 引入第二品牌色；success/warning/danger 只用于状态，星标与连接状态也不得扩散成大色块。
- **Don't** 为单个组件发明家族外的圆角，或把胶囊圆角用于普通容器。
- **Don't** 在选择动画中缩放、位移或改写标签文字，也不要在静止界面保留装饰性循环动画。
- **Don't** 把普通页面跳转改回横向翻页，也不要复制平台私有手势控制器；保留系统返回手势、取消行为和草稿保护。
