;;; init.el --- 由 Org 生成的 Emacs 配置 -*- lexical-binding: t; -*-
;; 本文件由 org_configs/self_config.org 生成；请修改 Org 源文件，不要直接改本文件。
;; 本文件由 Org 生成；注释也维护在 Org 代码块中，避免下次生成时丢失。
;; 已配置基础环境、基础编辑、界面、Org 目录、编辑搜索、文件项目、保存恢复和菜单；开发等仍占位。

;;; 基础入口

;; 平台识别先于包管理与状态路径执行；GUI 检测仍在后面的界面章节。
(defconst my/platform
  (cond
   ((eq system-type 'windows-nt) 'windows)
   ((eq system-type 'gnu/linux) 'linux)
   ((eq system-type 'darwin) 'macos)
   (t 'other))
  "供平台特有配置使用的系统标识。")

;; WORK PC 本机标识：当前 system-name 为 DESKTOP-QIGH8CJ，避免误作用于其他 Windows 电脑。
;; 电脑改名时修改这里；其他机器不应仅因为同为 Windows 就启用这些特例。
(defconst my/work-pc-p
  (and (eq my/platform 'windows)
       (string-equal (upcase (system-name)) "DESKTOP-QIGH8CJ"))
  "当前是否为需要 HOME 与 GPG 兼容处理的 WORK PC。")

;; 本机选项，不是跨平台默认家目录；必须在本章改值，晚于此处的 Custom 加载不能追溯初始化。
(defvar my/work-pc-home-directory "D:/Software/Msys2/home/HP/"
  "WORK PC 的统一 HOME；只在 my/work-pc-p 为非 nil 时使用。")

(when my/work-pc-p
  (unless (file-directory-p my/work-pc-home-directory)
    (error "WORK PC home directory not found: %s" my/work-pc-home-directory))
  ;; 尽早改变本 Emacs 进程及之后启动的子进程环境，不修改 Windows 系统环境。
  ;; 不能回溯改变已经发生的 init.el 搜索；现有 AppData 目录链接仍是有效启动入口。
  (setenv "HOME" (directory-file-name my/work-pc-home-directory))
  ;; 清除之前按旧 HOME 生成的文件名缩写缓存，使后续 ~ 显示采用新家目录。
  (setq abbreviated-home-dir nil))

;; 以 init.el 所在目录为根；WORK PC 解析目录链接，避免 AppData 与真实路径混用。
;; Linux/macOS 保持原有路径选择，不重写其 HOME 或用户配置目录。
(defconst my/config-directory
  (let ((directory (file-name-directory (or load-file-name user-init-file))))
    (if my/work-pc-p
        (file-name-as-directory (file-truename directory))
      directory))
  "保存本配置生成的 init.el 的目录。")

(when my/work-pc-p
  ;; 仅统一后续功能使用的配置目录；不会重选或重新加载本次 init.el。
  ;; 不修改 user-init-file，它保留本次启动实际采用的入口路径，便于排查。
  (setq user-emacs-directory my/config-directory))

;; 等命令行文件参数处理完成后，再统一起始页面目录；不破坏相对文件参数的解析基准。
(defun liyunfeng/work-pc-start-directory ()
  "将 WORK PC 的起始页面目录设为统一 HOME，保留文件缓冲区目录。"
  (dolist (name '("*scratch*" "*Messages*" "*my dashboard*"))
    (when-let* ((buffer (get-buffer name)))
      (with-current-buffer buffer
        (unless buffer-file-name
          (setq default-directory (file-name-as-directory my/work-pc-home-directory)))))))

(when my/work-pc-p
  ;; append=t：在 Dashboard 等启动入口之后调整；不改 command-line-default-directory。
  (add-hook 'emacs-startup-hook #'liyunfeng/work-pc-start-directory t))

;; 关闭原生欢迎页；scratch 保留加载提示，无文件启动另由 Dashboard 提供起始页。
(setq inhibit-startup-screen t
      initial-scratch-message ";; Org config loaded successfully.\n\n")
;; t 表示跳过启动欢迎页；scratch 提示只用于确认配置已读取，可改为 nil 或空字符串。

;;; 文本编码与换行：新文件默认 UTF-8 Unix，已有文本在保存时统一转换。
;; prefer-coding-system 提高读取识别时的 UTF-8 优先级，并设置默认写入编码。
;; 仍保留其他编码的自动识别；不强制把 GBK 等已有文件当成 UTF-8 解码。
(prefer-coding-system 'utf-8-unix)
(setq-default buffer-file-coding-system 'utf-8-unix)
;; require-final-newline 默认 nil；本配置选择 t，保存时补齐文件末尾换行。
;; mode-require-final-newline 默认 t：供会局部设置该选项的主模式使用。
(setq-default require-final-newline t
              mode-require-final-newline t)

(defun my/save-text-as-utf-8-unix ()
  "保存普通文本文件时使用不带 BOM 的 UTF-8 编码及 LF 换行。"
  (when (and buffer-file-name
             (derived-mode-p 'text-mode 'prog-mode)
             (not (eq (coding-system-base buffer-file-coding-system)
                      'no-conversion)))
    ;; 明确指定编码和换行方式；不继承原文件的 dos（CRLF）或带 BOM 编码。
    ;; 第三个参数 t 避免仅设置编码就额外把缓冲区标为已修改。
    (set-buffer-file-coding-system 'utf-8-unix t t)
    (setq-local require-final-newline t)))

;; 与手动保存及已有自动保存共用；不新增保存计时器，不批量改写磁盘文件。
;; before-save-hook 在写入文件前执行；add-hook 只登记函数，不会现在保存文件。
;; #' 引用前面定义的函数；函数会自行判断是否为适用的文本文件，再统一编码。
(add-hook 'before-save-hook #'my/save-text-as-utf-8-unix)

;;; Custom 状态独立保存，避免污染由 Org 生成的 init.el。
;; 尽早设置：首次安装插件时，包选择记录也应写到 custom.el。
(setq custom-file (expand-file-name "custom.el" my/config-directory))
(load custom-file 'noerror 'nomessage)

;;; 网络代理
;; 仅影响 Emacs URL 库，不会替 Git、clangd 等外部程序设置代理。
(require 'url-vars)

;; 不需要显式代理时改为 nil；已有的进程代理环境变量不受此设置清除。
(defvar my/proxy-address "127.0.0.1:10808"
  "本地 HTTP 代理地址；设为 nil 表示不设置显式 URL 代理。")

;; HTTP/HTTPS 共用本地 HTTP 代理，本机地址绕过代理。
(setq url-proxy-services
      (when my/proxy-address
        `(("http" . ,my/proxy-address)
          ("https" . ,my/proxy-address)
          ("no_proxy" . "\\`\\(localhost\\|127\\.0\\.0\\.1\\|\\[::1\\]\\)\\'"))))

;;; 软件包目录与 ELPA 软件源
(require 'package)

;; 插件安装在配置目录下的 elpa/；同名包优先 GNU，其次 NonGNU，再其次 MELPA。
(setq package-user-dir (expand-file-name "elpa/" my/config-directory)
      package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/"))
      package-archive-priorities
      '(("gnu" . 30) ("nongnu" . 20) ("melpa" . 10)))

;;; 本机特例：MSYS2 GPG 路径兼容，以及资源管理器启动时缺少 GPG 的回退。
;; 仅在找不到当前 GPG 或命中已知问题路径时，使用本机已存在的 Git GPG。
;; 保留其他已发现的 GPG；非 WORK PC 不执行此回退，不关闭签名校验。
(when my/work-pc-p
  (require 'epg-config)
  (let ((detected (executable-find epg-gpg-program))
        (affected "D:/Software/Msys2/usr/bin/gpg.exe")
        (replacement "D:/Software/Git/usr/bin/gpg.exe"))
    (when (and (file-executable-p replacement)
               (or (null detected)
                   (string-equal (downcase detected) (downcase affected))))
      ;; EasyPG 会检查自定义状态；仅 setq 可能仍让它重新从 PATH 选择程序。
      (customize-set-variable 'epg-gpg-program replacement)
      ;; 清除指向旧 GPG 的配置缓存，让后续校验使用替代程序。
      (setq epg--configurations nil))))

;;; WORK PC 额外签名密钥环修复；后面的包激活与索引初始化各平台共用。
;; 保留签名校验，不修改个人日常使用的 GPG 密钥环。
;; 必须是独立的顶层表达式：先加载结构定义，再展开下一个表达式中的 setf。
;; 不能把 require 和 setf 仅放进同一个 when，首次加载时赋值规则可能尚不可用。
(when my/work-pc-p
  (require 'epg))

(when my/work-pc-p
  ;; 仅 WORK PC 主动检查、修复 ELPA 密钥环；其他机器采用 package.el 自身默认流程。
  (setq package-gnupghome-dir (expand-file-name "gnupg/" package-user-dir))
  (unless (epg-find-configuration 'OpenPGP)
    (error "GnuPG not found or unusable; check WORK PC GPG settings"))
  (let ((context (epg-make-context 'OpenPGP)))
    (setf (epg-context-home-directory context) package-gnupghome-dir)
    ;; 初次使用或之前初始化失败留下空密钥环时，导入 Emacs 自带的 ELPA 公钥。
    (unless (epg-list-keys context)
      (package-import-keyring (expand-file-name "package-keyring.gpg" data-directory)))))

;; 激活已经安装的插件；此操作本身不更新或升级它们。
(package-initialize)

;; 仅在交互启动且某个源缺少缓存索引时刷新，不在每次启动时联网。
;; 更新索引可用 M-x package-refresh-contents；刷新索引不等于升级插件。
(when (and (not noninteractive)
           (not (seq-every-p
                 (lambda (archive)
                   (file-exists-p
                    (expand-file-name
                     (concat "archives/" (car archive) "/archive-contents")
                     package-user-dir)))
                 package-archives)))
  (package-refresh-contents))

;;; use-package 声明管理
;; Emacs 29+ 使用内置版本；旧版本缺失时才从软件源安装。
(unless (require 'use-package nil t)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'use-package)
  (require 'use-package))

;; 后续第三方插件默认自动安装；内置功能应显式声明 :ensure nil。
(setq use-package-always-ensure t)

;;; 平台标识 my/platform 已在基础入口定义；这里仅定义图形 Frame 检测。
(defun my/graphic-frame-p (&optional frame)
  "判断 FRAME 是否为图形 Emacs 帧。"
  (display-graphic-p (or frame (selected-frame))))

(defconst my/graphic-session-p (my/graphic-frame-p)
  "记录初始 Emacs 会话是否有图形帧。")

;;; 基础界面：使用内置菜单、工具提示和 Frame 参数。
;; 本配置显式启用菜单栏；改为 -1 可关闭，命令仍可通过 M-x 调用。
(menu-bar-mode 1)

(defun my/setup-graphic-frame (frame)
  "为图形 FRAME 设置精简工具界面和明确的最大化状态。"
  (when (my/graphic-frame-p frame)
    (with-selected-frame frame
      ;; -1 关闭工具栏和滚动条；1 启用 tooltip 鼠标帮助弹窗。
      (tool-bar-mode -1)
      (scroll-bar-mode -1)
      (tooltip-mode 1)
      ;; 本配置选择 maximized；改为 fullboth 为全屏，nil 为普通窗口。
      (set-frame-parameter frame 'fullscreen 'maximized))))

;; 只影响图形 Frame；新建 Frame 时同样处理，不依赖启动时是否已有图形窗口。
(my/setup-graphic-frame (selected-frame))
;; 上一行立即处理已有 Frame；这里登记以后每次创建 Frame 后要执行的函数。
;; after-make-frame-functions 会把新 Frame 作为参数传入，函数内部跳过终端 Frame。
(add-hook 'after-make-frame-functions #'my/setup-graphic-frame)

;; 内置默认 ring-bell-function=nil、visible-bell=nil；本配置选择完全静音。
;; 如需可视提醒，把 ignore 改为 nil，保留 visible-bell=t；效果取决于显示环境。
;; 如需默认声音提醒，把 ring-bell-function 和 visible-bell 都改为 nil。
(setq ring-bell-function #'ignore
      visible-bell t)

(use-package mwheel
  :ensure nil                         ; 内置鼠标滚轮支持，不安装第三方包。
  :demand t                           ; 先加载滚轮定义，再设置修饰键对应的行为。
  :custom
  ;; 本配置沿用参考列表：1 为一行；Shift 为一行；Ctrl 的 nil 是近一屏，不是禁用。
  ;; Emacs 31.1 默认 Shift=hscroll、Ctrl=text-scale；想恢复时替换对应值即可。
  (mouse-wheel-scroll-amount '(1 ((shift) . 1) ((control) . nil)))
  ;; 插件默认 t：滚得越快额外加速；本配置 nil：关闭这层加速。
  (mouse-wheel-progressive-speed nil))

;; 行号和当前行提示使用内置功能；特殊工具界面不显示行号。
;; 内置默认 t 为绝对行号；本配置选择 'relative，相邻行显示距离，方便 3j / 5k。
;; 改回 t 恢复绝对行号；当前行保留绝对行号，relative 不按屏幕折行计数。
;; display-line-numbers-width=3 预留三列；数字较多时可改为 4 或 nil 让 Emacs 自动计算。
(setq-default display-line-numbers-type 'relative
              display-line-numbers-width 3
              ;; 内置默认 t，本配置保持：当前行显示绝对行号，而非 0。
              display-line-numbers-current-absolute t)
;; 状态栏独立显示绝对行号和列号；均使用内置模式，不新增插件。
;; line-number-mode 默认开启；column-number-mode 默认关闭，本配置显式开启。
(line-number-mode 1)
(column-number-mode 1)
;; 全局默认开启行号，再通过下面的 hook 排除工具界面；Org 不在排除列表中。
(global-display-line-numbers-mode 1)
;; hook 是进入某个模式时自动执行的动作列表；minibuffer-setup-hook 在进入输入区时执行。
;; dolist 逐个取出下面的 hook 名称，add-hook 为它登记关闭行号的动作。
;; lambda () 表示一个不需要参数的临时函数：这里只登记，进入对应界面时才执行。
;; 增加排除项就往列表里加对应的 xxx-mode-hook；行号与高亮列表可分别调整。
(dolist (hook '(magit-mode-hook dired-mode-hook minibuffer-setup-hook
                help-mode-hook helpful-mode-hook compilation-mode-hook
                shell-mode-hook term-mode-hook eshell-mode-hook dashboard-mode-hook))
  (add-hook hook (lambda ()
                   ;; -1 明确关闭当前缓冲区的行号，不是反复切换开／关。
                   (display-line-numbers-mode -1))))
;; 全局默认开启当前行高亮；下面为同一批工具界面登记关闭动作。
(global-hl-line-mode 1)
;; 与上面同理：逐个向 hook 添加函数，进入相应界面时才局部关闭高亮。
(dolist (hook '(minibuffer-setup-hook magit-mode-hook dired-mode-hook
                help-mode-hook helpful-mode-hook compilation-mode-hook
                shell-mode-hook term-mode-hook eshell-mode-hook dashboard-mode-hook))
  (add-hook hook (lambda ()
                   ;; 全局模式有独立的 overlay；只关闭局部模式不能阻止它再次高亮。
                   ;; setq-local 只改变当前缓冲区的值，不关闭其他文件中的全局高亮。
                   (setq-local global-hl-line-mode nil)
                   ;; 清除当前缓冲区已有的全局高亮覆盖层，避免旧背景残留。
                   (global-hl-line-unhighlight)
                   ;; 同时关闭可能单独开启的局部高亮模式。
                   (hl-line-mode -1))))

(use-package cnfonts
  :demand t                           ; 启动时加载；图形 Frame 应用正文，终端字体由终端控制。
  :custom
  ;; 插件默认 (locate-user-emacs-file "cnfonts/")；本配置放到 .cache/cnfonts/，该目录已被 Git 忽略。
  (cnfonts-directory (expand-file-name ".cache/cnfonts/" my/config-directory))
  ;; 插件默认 '("profile1" "profile2" "profile3")；本配置只用一个存档 "main"。
  ;; 存档名决定输出文件名 .cache/cnfonts/v4/main.el，以及 cnfonts.conf 里的记录名。
  (cnfonts-profiles '("main"))
  ;; 插件默认 12.5；本配置选择 10。它是“英文字号”，中文等组的字号由字号表按英文字号配套（10 对应中文 12）。
  ;; 注意它只是初始值：.cache/cnfonts/cnfonts.conf 已有 main 的记录时以记录为准，见下文“数值存放在哪里”。
  (cnfonts-default-fontsize 10)
  ;; 插件默认 nil。五组字体，依次是 英文、中文、EXT-B（生僻汉字）、符号、装饰字符；本配置只写前两组。
  ;; 同一组内越靠前越优先，cnfonts 取“系统里已安装的第一款”，所以备选字体写在同一组后面，例如：
  ;;   英文 '("JetBrainsMono NFM" "备选英文字体B" "备选英文字体C")
  ;;   中文 '("LXGW WenKai Mono GB" "备选中文字体B" "备选中文字体C")
  ;; cnfonts 会在你的列表之后自动追加它的内置候选（Monaco、微软雅黑等），这一点不能关闭。
  ;; 修改后必须同时处理 main.el，见下文“更换字体或增加备选”。
  (cnfonts-personal-fontnames
   '(("JetBrainsMono NFM")              ; 英文
     ("LXGW WenKai Mono GB")))          ; 中文
  :config
  ;; cnfonts 保存字号时不会创建目录；.cache/ 在新环境里还不存在，先建好，否则初始化报错。
  (make-directory cnfonts-directory t)
  ;; 插件原生：之后在每个新建的图形 Frame 和窗口准备完成时自动应用字体。
  (cnfonts-mode 1)
  ;; 提前应用一次。cnfonts-mode 默认在 window-setup-hook 才应用字体，晚于 Dashboard 的创建；
  ;; Dashboard 插入图标时用 char-displayable-p 检查默认字体，当时字体还没换成带图标字形的
  ;; JetBrainsMono NFM，图标会被丢弃。终端 Frame 不适用，跳过。
  (when (display-graphic-p)
    (cnfonts-set-font))
  )

;;; 主题：直接加载暗色 doom-one；换主题改下面的符号，临时试用见正文说明。
(use-package doom-themes
  :demand t
  :config
  ;; 第二个参数 t 表示不再询问是否信任主题代码；浅色可换成 'doom-one-light。
  (load-theme 'doom-one t))

;;; 状态栏：成熟的 mode-line 布局，固定使用 Nerd Icons。
(use-package nerd-icons
  :demand t                           ; 图标包；字体另需系统安装 Symbols Nerd Font Mono。
  :custom
  ;; 插件默认 1.0；本配置选择 1.3。所有 Nerd 图标的统一缩放倍数，同时作用于状态栏左侧的
  ;; Vim 状态图标、文件类型图标、Dashboard 图标，以及这些图标的垂直微调量。
  ;; 想更大改成 1.5；想回到原大小改成 1.0。数值过大时图标可能撑高状态栏或与文字错位。
  (nerd-icons-scale-factor 1.3))

(use-package doom-modeline
  :demand t
  :custom
  ;; 高度选择 24 像素；只影响图形界面，终端由字符高度决定，可按显示器调整。
  (doom-modeline-height 24)
  ;; 插件默认在图形界面为 t；这里显式写出。nil 使用文字布局。
  (doom-modeline-icon t)
  ;; 显示主模式图标；nil 只隐藏图标，不影响主模式名称。
  (doom-modeline-major-mode-icon t)
  ;; 文件名过长时使用省略号截断；改为 nil 可尝试显示完整路径，但会占用更多宽度。
  (doom-modeline-buffer-file-name-style 'truncate-ellipsis)
  :config
  (doom-modeline-mode 1))

;;; 可选 mode-line 装饰：默认只有彩虹小猫开启，其余包不会自动安装。
(defcustom my/enable-nyan-mode t
  "是否显示表示缓冲区位置的彩虹小猫。"
  :type 'boolean)
;; 默认 t；改为 nil 并重启可关闭彩虹小猫，避免与 poke-line 同时占用位置。
(defcustom my/enable-poke-line nil
  "是否显示宝可梦位置指示器；启用时应关闭彩虹小猫。"
  :type 'boolean)
;; 默认 nil；改为 t 前先把 my/enable-nyan-mode 改为 nil。
(defcustom my/enable-parrot nil
  "是否启用状态栏中的动画鹦鹉。"
  :type 'boolean)
;; 默认 nil；改为 t 后 parrot 会接管自己的动画触发逻辑。
(defcustom my/enable-emacs-pets nil
  "是否启用可选的 Emacs 宠物动画。"
  :type 'boolean)
;; 默认 nil；启用前先确认包和宠物资源可从软件源取得。
(defcustom my/enable-flappy-fish nil
  "是否启用可选的状态栏小鱼动画。"
  :type 'boolean)
;; 默认 nil；这是独立的状态栏动画，启用后需检查窄窗口中的布局。

(when (and my/enable-nyan-mode my/enable-poke-line)
  (error "Enable only one of my/enable-nyan-mode and my/enable-poke-line"))
(when my/enable-nyan-mode
  (use-package nyan-mode
    :demand t                          ; 启动时加载位置指示器，随后启用模式。
    :custom
    ;; 插件默认 nil；本配置沿用参考设为 t，让小猫持续播放动画；nil 为静态显示。
    (nyan-animate-nyancat t)
    ;; 插件默认 nil；本配置沿用参考设为 t，让彩虹尾迹呈波浪状。
    ;; 本机版本源码仍保留此效果的已知问题备注，实际外观需在当前显示环境确认。
    (nyan-wavy-trail t)
    ;; 插件默认 0.2 秒，本配置保持；越小动画越快、刷新越频繁，例如 0.4 会更慢。
    (nyan-animation-frame-interval 0.2)
    ;; 插件默认 32 单位，本配置保持；每单位是 8px 图像，图形轨道约 256px，最少 3 单位。
    ;; 这是轨道的总显示宽度，不是文件长度；可改为 16 或 24 给其他状态栏信息让出空间。
    (nyan-bar-length 32)
    :config (nyan-mode 1)))
(when my/enable-poke-line
  (use-package poke-line
    :demand t
    :config (poke-line-mode 1)))
(when my/enable-parrot
  (use-package parrot
    :demand t
    :config (parrot-mode 1)))
(when my/enable-emacs-pets
  (use-package emacs-pets
    :demand t
    :config (emacs-pets-mode 1)))
(when my/enable-flappy-fish
  (use-package flappy-fish
    :demand t
    :config (flappy-fish-mode 1)))

;;; Org 自动目录
;; Org 缓冲区启用 toc-org，但只为带 TOC 标签的文档在保存时更新目录。
;; 本配置文档使用 :TOC_4_org:；目前目录只有标题链接，不包含章节编号。
;; 不配置全局 org-num hook；正文编号由每份文件的 #+startup: num 决定。
(use-package toc-org
  ;; :hook 让每个 Org 缓冲区启用 toc-org；插件只在文档有 TOC 标签时更新目录。
  ;; (org-mode . toc-org-mode) 表示进入 org-mode 时调用 toc-org-mode。
  ;; use-package 自动补成 org-mode-hook，并提供按需加载；无需再重复写 add-hook。
  :hook (org-mode . toc-org-mode))

;;; Org 外观渲染：内置显示选项 + org-modern + org-appear。
(use-package org
  :ensure nil
  :custom
  ;; 内置默认 nil：显示 *粗体* 的星号等标记符；本配置选择 t：隐藏标记，只显示格式效果。
  ;; 光标进入标记处时由下面的 org-appear 临时显示原文，方便修改。
  (org-hide-emphasis-markers t)
  ;; 内置默认 nil：不把 \alpha 之类实体显示为符号；保持默认，避免正文里的反斜杠被改写显示。
  (org-pretty-entities nil)
  ;; 内置默认 t：链接只显示描述文字 [[url][描述]] → 描述；改为 nil 则显示完整原文。
  (org-link-descriptive t)
  ;; 内置默认 nil：折叠标题后的省略号使用 "..."；可改为 " ▾" 等字符串。
  (org-ellipsis nil)
  ;; 内置默认 nil：打开文件时不自动显示图片；改为 t 则自动内联显示 [[file:x.png]] 图片。
  (org-startup-with-inline-images nil))

(use-package org-modern
  ;; :hook 在每个 Org 缓冲区启用美化；agenda 视图本配置未使用，不添加 org-modern-agenda。
  :hook (org-mode . org-modern-mode)
  :custom
  ;; 以下为插件 1.15 全部 defcustom；除标注“本配置选择”外均为插件默认值。
  ;; 标签边框宽度；整数为像素，小数为字符高度的比例。默认 0.1。
  (org-modern-label-border 0.1)
  ;; 标题星号样式：fold（默认，用 ▶▼ 表示折叠状态）、replace（用下面的符号替换）、nil（不处理）。
  (org-modern-star 'fold)
  ;; 很深的标题是否循环使用符号。默认 nil：超出后重复使用最后一个。
  (org-modern-cycle-stars nil)
  ;; star 为 replace 时每一级使用的符号，默认 "◉○◈◇✳"；本配置未用 replace，仅供切换时使用。
  (org-modern-replace-stars "◉○◈◇✳")
  ;; star 为 fold 时每一级的（折叠 . 展开）符号对，默认值如下。
  (org-modern-fold-stars
   '(("▶" . "▼") ("▷" . "▽") ("⯈" . "⯆") ("▹" . "▿") ("▸" . "▾")))
  ;; 隐藏前导星号：leading（默认，只保留最后一个）、t（全部隐藏）、nil（不隐藏）、字符/字符串（替换）。
  (org-modern-hide-stars 'leading)
  ;; 美化时间戳。默认 t；nil 关闭；也可设 (" %Y-%m-%d " . " %H:%M ") 自定义格式。
  (org-modern-timestamp t)
  ;; 美化表格。插件默认 t；本配置选择 nil：与 valign 同时画表格线会让分隔行错位，
  ;; 表格线条和列对齐统一交给 valign。下面两项仅在改回 t 时才生效。
  (org-modern-table nil)
  ;; 表格竖线宽度（像素），默认 3；nil 隐藏竖线。
  (org-modern-table-vertical 3)
  ;; 表格横线粗细，默认 0.1；nil 不美化横线。
  (org-modern-table-horizontal 0.1)
  ;; 美化优先级 [#A]。默认 t：隐藏方括号；也可设 ((?A . "❗") (?B . "⬆") (?C . "⬇")) 自定义。
  (org-modern-priority t)
  ;; 无序列表符号替换，默认如下；设为 nil 不处理列表符。
  (org-modern-list '((?+ . "◦") (?- . "–") (?* . "•")))
  ;; 复选框符号替换，默认如下；设为 nil 不处理复选框。
  (org-modern-checkbox
   '((?X . "☑") (?- . #("□–" 0 2 (composition ((2))))) (?\s . "□")))
  ;; 美化水平分隔线 -----。默认 t；nil 关闭；也可设字符串作为替换。
  (org-modern-horizontal-rule t)
  ;; 美化 TODO 关键字，默认 t；nil 关闭。
  (org-modern-todo t)
  ;; 为指定 TODO 关键字设置 face，默认 nil；例如 '(("TODO" . error))。
  (org-modern-todo-faces nil)
  ;; 为指定标签设置 face，默认 nil；例如 '(("work" . success))。
  (org-modern-tag-faces nil)
  ;; 为指定优先级设置 face，默认 nil；例如 '((?A . error))。
  (org-modern-priority-faces nil)
  ;; 美化标题标签 :tag1:tag2:，默认 t；nil 关闭。
  (org-modern-tag t)
  ;; 美化 #+begin_ / #+end_ 行。默认 t：隐藏前缀；也可设 ("‣" . "‣") 用符号替换。
  (org-modern-block-name t)
  ;; 代码块左侧条纹边框。默认 2：距窗口边缘 2 像素；0～16 调位置，nil 关闭。
  ;; 启用 org-indent-mode 时自动停用。
  (org-modern-block-fringe 2)
  ;; 美化 #+title: 等关键字。默认 t：隐藏 #+；设字符串如 "‣" 则替换；nil 关闭。
  (org-modern-keyword t)
  ;; 脚注显示，默认值为 (nil . 上标样式)：定义保持原样，引用显示为上标。
  (org-modern-footnote (cons nil (cadr org-script-display)))
  ;; 内部链接目标 <<目标>> 的显示，默认如下；nil 关闭。
  (org-modern-internal-target '(" ↪ " t " "))
  ;; 广播目标 <<<目标>>> 的显示，默认如下；nil 关闭。
  (org-modern-radio-target '(" ⛯ " t " "))
  ;; 进度条 [1/3] 的宽度（字符数），默认 12；nil 不画进度条。
  (org-modern-progress 12))

(use-package org-appear
  ;; :hook 在每个 Org 缓冲区启用；与 org-hide-emphasis-markers 配合才能看到效果。
  :hook (org-mode . org-appear-mode)
  :custom
  ;; 以下为插件 0.3.1 全部 defcustom，均为插件默认值。
  ;; 触发方式：always（默认，光标进入即显示）、on-change（修改缓冲区或鼠标点击时才显示）、
  ;; manual（需手动调用 org-appear-manual-start / org-appear-manual-stop）。
  (org-appear-trigger 'always)
  ;; 光标进入时显示强调与 verbatim 标记符，默认 t；依赖 org-hide-emphasis-markers 为非 nil。
  (org-appear-autoemphasis t)
  ;; 显示上下标标记符，默认 nil；依赖 org-pretty-entities 为非 nil（当前为 nil，不生效）。
  (org-appear-autosubmarkers nil)
  ;; 显示 Org 实体（如 \alpha）原文，默认 nil；依赖 org-pretty-entities 为非 nil。
  (org-appear-autoentities nil)
  ;; 显示链接原文，默认 nil：t 为完整链接，just-brackets 只显示括号；依赖 org-link-descriptive。
  (org-appear-autolinks nil)
  ;; 显示被隐藏的关键字，默认 nil；依赖 org-hidden-keywords，当前未设置。
  (org-appear-autokeywords nil)
  ;; 是否在 LaTeX 片段与环境内也触发，默认 nil。
  (org-appear-inside-latex nil)
  ;; 显示前的延迟秒数，默认 0.0：立即显示。
  (org-appear-delay 0.0)
  ;; manual 模式停止后是否保持显示，默认 nil：停止即隐藏；t 则离开元素后才隐藏。
  (org-appear-manual-linger nil))

;;; 表格像素对齐：修正中文、图标、变宽字体造成的列错位。
(use-package valign
  ;; :hook 在 Org 与 Markdown 缓冲区启用；终端 Emacs 里不会生效。
  :hook ((org-mode markdown-mode) . valign-mode)
  :custom
  ;; 以下为插件 3.1.1 全部 defcustom；除标注“本配置选择”外均为插件默认值。
  ;; 模式行标识，默认 " valign"。
  (valign-lighter " valign")
  ;; 表格竖线显示为整行高的线。默认 nil：普通 | 字符，按像素对齐；本配置保持 nil。
  ;; 想试整行高竖线可改为 t，若分隔行出现错位则改回；修改后需重新开关 valign-mode 才生效。
  (valign-fancy-bar nil)
  ;; 这些命令执行后不立即重新对齐，避免输入时闪动。默认如下；可增删命令名。
  (valign-not-align-after-list
   '(self-insert-command org-self-insert-command markdown-outdent-or-delete
     org-delete-backward-char backward-kill-word delete-char kill-word))
  ;; 超过此大小（字符数）的表格不对齐，改用 valign-table-fallback 的等宽字体。默认 4000；0 表示不限制。
  (valign-max-table-size 4000))

;;; Markdown 渲染：隐藏标记、标题放大、代码块高亮。
(use-package markdown-mode
  ;; :mode 将 .md／.markdown 关联到该模式；README.md 使用 GFM 方言（支持表格、任务列表）。
  :mode (("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode)
         ("README\\.md\\'" . gfm-mode))
  :custom
  ;; markdown-mode 有数百个选项；下面只列与“渲染”相关的，取值对照 2.9-alpha 源码。
  ;; 隐藏 **粗体**、# 等标记符。默认 nil；本配置选择 t。光标所在行不会自动还原，
  ;; 需要查看原文时 M-x markdown-toggle-markup-hiding。
  (markdown-hide-markup t)
  ;; 隐藏链接地址只显示文字。默认 nil；保持默认，以便查看和复制地址。
  (markdown-hide-urls nil)
  ;; 标题按级别放大。默认 nil；本配置选择 t，比例见下一项。
  (markdown-header-scaling t)
  ;; 一到六级标题的放大倍数，默认 (2.0 1.7 1.4 1.1 1.0 1.0)。
  (markdown-header-scaling-values '(2.0 1.7 1.4 1.1 1.0 1.0))
  ;; 无序列表符号，默认 ("●" "◎" "○" "◆" "◇" "►" "•")，按嵌套层级循环使用。
  (markdown-list-item-bullets '("●" "◎" "○" "◆" "◇" "►" "•"))
  ;; 用对应语言的主模式高亮围栏代码块。默认 nil；本配置选择 t，语言名写在 ``` 后面。
  (markdown-fontify-code-blocks-natively t)
  ;; 整行标题套用标题样式（含背景色）。默认 nil。
  (markdown-fontify-whole-heading-line nil)
  ;; 行内数学公式 $...$ 的高亮。默认 nil。
  (markdown-enable-math nil)
  ;; Wiki 链接 [[...]] 高亮。默认 nil。
  (markdown-enable-wiki-links nil)
  ;; 下载并显示远程图片。默认 nil：避免打开文件时自动联网。
  (markdown-display-remote-images nil)
  ;; 内联图片的最大宽高。默认 nil：按原尺寸；可设 (800 . 600)（像素）。
  (markdown-max-image-size nil)
  ;; 只读查看模式（markdown-view-mode）中也隐藏标记符。默认 t。
  (markdown-hide-markup-in-view-modes t)
  ;; 插入斜体时使用 _ 而非 *。默认 nil。
  (markdown-italic-underscore nil)
  ;; 插入 # 标题时是否只在行首加 #。默认 t（非对称，如“# 标题”）；nil 则两侧都加。
  (markdown-asymmetric-header t))

(use-package delsel
  :ensure nil                         ; 内置选区替换，不需要安装插件。
  :demand t                           ; 启动时加载并立即启用全局选区替换。
  :config
  ;; 内置默认关闭；本配置沿用参考选择启用，改为 -1 可关闭。
  (delete-selection-mode 1))

;;; Vim 风格编辑：Evil。
;; 必须先关闭 Evil 自带的部分模式键位，交由 evil-collection 统一适配。
;; 这是加载前选项，必须放在 :init；自定义按键集中在文件末尾。
(use-package evil
  ;; :demand t 启动时立即启用 Evil；:init 中的变量必须在加载前设置。
  :demand t
  :init
  (setq evil-want-keybinding nil
        ;; 插件默认 nil：C-u 传递 Emacs 前缀参数；本配置 t：采用 Vim 向上半屏滚动。
        ;; 必须在 Evil 加载前设置；C-d 继续向下半屏，其他状态以有效键位为准。
        evil-want-C-u-scroll t)
  :config
  ;; Evil 1.15.0 仍读取旧的初始化队列；Emacs 31.1 不再创建该变量。
  ;; 只在已知版本组合且变量未定义时补空队列，不覆盖其他版本或已有状态。
  (when (and (version= emacs-version "31.1")
             (string= evil-version "1.15.0")
             (not (boundp 'evil-mode-buffers)))
    (set-default 'evil-mode-buffers nil))
  (evil-mode 1))

;;; 工具界面的 Vim 风格键位。
;; 为 Dired、帮助等受支持模式适配键位；模式打开时按需应用。
(use-package evil-collection
  ;; :after 等待 Evil 先加载；:demand t 让已支持的工具界面立即完成适配。
  :after evil
  :demand t
  :config
  (evil-collection-init))

;;; 包围符操作：ys 加动作或文本对象再加新包围符；ds 删除旧包围符；cs 替换旧包围符。
;; iw/aw 是普通文本对象；ysiw" 包整个词，yse" 包到词尾。详见 Org 中的语法说明。
(use-package evil-surround
  ;; :after 等待 Evil 先加载；全局模式启用后，ys/ds/cs 适用于支持的缓冲区。
  :after evil
  :demand t
  :config
  (global-evil-surround-mode 1))

;;; 快速注释：gc 加动作注释／取消注释，gcc 注释当前行，可视状态选中后按 gc。详见 Org 中的操作说明。
(use-package evil-commentary
  ;; :after 等待 Evil 先加载；它是 Evil 操作符，没有 Evil 就没有意义。
  :after evil
  :demand t                           ; 启动时启用全局模式，gc／gy 才会立即可用。
  :config
  ;; 全局模式，只需启用一次；键位 gc、gy 由插件定义，没有写入统一快捷键章节（见下文说明）。
  (evil-commentary-mode 1))

;;; 屏幕内定位：按命令加载，不在启动时扫描缓冲区。
(use-package avy
  ;; 为菜单使用的命令建立自动加载入口；首次调用才加载 Avy，不是在这里设置快捷键。
  :commands (avy-goto-char-timer avy-goto-line avy-goto-char avy-goto-word-0
             avy-goto-word-1 avy-pop-mark)
  :custom
  ;; 本配置选择 nil：当前窗口；插件默认 t：当前 Frame 全部窗口；all-frames：全部 Frame。
  (avy-all-windows nil)
  ;; 默认 0.5 秒：连续字符输入停顿多久后显示标签；可改为 0.8 或 1.0，给输入更多时间。
  (avy-timeout-seconds 1.0)
  ;; 默认 t：RET 提前结束文字输入并显示标签；nil 则把 RET 当作换行字符匹配。
  (avy-enter-times-out t)
  ;; 默认 t：匹配文字忽略大小写；改为 nil 后区分大小写。
  (avy-case-fold-search t)
  ;; 插件默认标签为 a s d f g h j k l；下面保留个人选择。?a 表示字符 a，可调整顺序。
  (avy-keys '(?a ?o ?e ?u ?i ?d ?h ?t ?n)))

;;; 候选界面：默认候选数量，按内容动态增减高度，不首尾循环。
(use-package vertico
  :custom
  (vertico-count 10)   ; 默认 10：最多显示的候选数；可改为 15 或 20，受窗口高度限制。
  (vertico-resize t)   ; 按已选行为动态增减高度；nil 固定高度，grow-only 只增高不缩小。
  (vertico-cycle nil)  ; 默认 nil：首尾不循环；改为 t 后从末尾继续向下会回到开头。
  :init
  (vertico-mode 1))    ; 启动时启用全局候选界面；1 是启用，不是候选数量。

;;; 悬浮候选窗口：仅作用于 Vertico 的显示位置，Orderless／Marginalia／Consult 照常工作。
(use-package vertico-posframe
  :after vertico
  :custom
  ;; 以下 14 项为插件 0.9.2 全部 defcustom；除标注“本配置选择”外均为插件默认值。
  ;; 无法正常创建悬浮窗口（如终端）时回退启用的模式。默认 #'ignore：不启用任何模式，
  ;; 直接用普通底部 minibuffer；可改为 #'ignore 以外的 minor mode 函数作为替代显示。
  (vertico-posframe-fallback-mode #'ignore)
  ;; 悬浮窗口字体。默认 nil：沿用当前 Frame 字体；可设字体名字符串，如 "Menlo-14"。
  (vertico-posframe-font nil)
  ;; 悬浮窗口宽度（字符数）。默认 nil：由 size-function 自适应；如 100 则最宽 100 列。
  (vertico-posframe-width nil)
  ;; 悬浮窗口高度（行数）。默认 nil：随候选数量自适应；如 15 则最高 15 行。
  (vertico-posframe-height nil)
  ;; 最小宽度（字符数）。默认 nil：取 Frame 宽度的 62%（见 size-function）；可设固定数字。
  (vertico-posframe-min-width nil)
  ;; 最小高度（行数）。默认 nil：取 vertico-count + 1；可设固定数字。
  (vertico-posframe-min-height nil)
  ;; 是否截断过长行。默认 t：截断不换行；nil 则自动折行显示完整内容。
  (vertico-posframe-truncate-lines t)
  ;; 悬浮窗口位置。插件默认 posframe-poshandler-frame-center（Frame 正中）；
  ;; 本配置选择 posframe-poshandler-frame-bottom-center（底部居中）。这是所有命令的默认位置，
  ;; 下面 vertico-multiform-commands 里写了条目的命令会覆盖它。
  ;; 可改为 posframe-poshandler-frame-top-center（顶部居中）等 posframe-poshandler-* 函数。
  (vertico-posframe-poshandler #'posframe-poshandler-frame-bottom-center)
  ;; 位置参考点函数（主要给 EXWM 用户）。默认 vertico-posframe-refposhandler-default；普通环境无需修改。
  (vertico-posframe-refposhandler #'vertico-posframe-refposhandler-default)
  ;; 计算窗口尺寸的函数。默认 vertico-posframe-get-size，它读取上面的 width／height／min-* 变量；
  ;; 自定义函数需接收候选 buffer，返回 (:height :width :min-height :min-width) 属性列表。
  (vertico-posframe-size-function #'vertico-posframe-get-size)
  ;; 边框像素宽度。默认 2；0 表示不显示边框。
  (vertico-posframe-border-width 2)
  ;; 额外 Frame 参数 alist。插件默认 nil；本配置选择：左右 fringe 各 8 像素，让文字不贴边。
  ;; 可再加 (alpha . 95) 等调整透明度（需系统支持）。
  (vertico-posframe-parameters '((left-fringe . 8) (right-fringe . 8)))
  ;; 命中规则时改回显示底部 minibuffer。默认 ("^eval-*")：命令名匹配该正则（如 eval-expression）；
  ;; 规则可为正则字符串、函数（返回非 nil 即命中）或值为 t 的变量符号。
  (vertico-posframe-show-minibuffer-rules (list "^eval-*"))
  ;; 在 vertico-multiform 中切换悬浮窗口的键。默认 "M-P"；本配置已在下方启用 vertico-multiform，
  ;; 因此在候选界面里按 M-P 可临时在悬浮窗和普通底部列表之间切换；设为 nil 表示不定义该键。
  (vertico-posframe-vertico-multiform-key "M-P")
  :config
  ;; 终端 Emacs（emacs -nw）无法创建子窗口：插件会自动回退到普通底部 minibuffer，
  ;; 回退模式默认 ignore，即什么都不额外做，因此全局启用是安全的。
  (vertico-posframe-mode 1))

;;; 按命令设置悬浮位置：预览类命令放在底部，避免挡住缓冲区里的预览。
(use-package vertico-multiform
  ;; vertico-multiform.el 随 vertico 包一起安装，不是独立插件；
  ;; :ensure nil 防止 use-package-always-ensure 去下载同名包而失败。
  :ensure nil
  :after vertico
  :custom
  ;; ── 怎么读这个列表 ────────────────────────────────────────────────────────
  ;; 每个条目长这样（三部分）：
  ;;   ("^命令名$"                                         ← ① 匹配哪个命令（见下方“命令对照”）
  ;;    (vertico-posframe-poshandler . 位置函数)            ← ② 这个命令用什么位置
  ;;    (vertico-posframe-width . 120))                    ← ③ 可选：再加别的设置，可以写多行
  ;; ① 是正则，^ 表示开头、$ 表示结尾，合起来就是“名字必须完全等于它”；
  ;;    要一次匹配多个命令，写成 "^\\(命令甲\\|命令乙\\)$"，其中 \\| 读作“或”。
  ;; ② 常用位置函数：posframe-poshandler-frame-center（正中）、frame-top-center（顶部居中）、
  ;;    frame-bottom-center（底部居中）、window-bottom-center（当前窗口底部），
  ;;    前缀都是 posframe-poshandler-。
  ;; 生效规则：从上到下找第一个匹配的条目，不叠加，所以特殊的写前面、宽泛的写后面。
  ;; 没有条目的命令使用上面 vertico-posframe-poshandler 的全局值（当前为底部居中）。
  ;; 条目里的设置只在这一次输入期间生效，输入结束后自动恢复。
  ;; 若加 (t ...) 作为兜底项，必须放最后，否则它会匹配所有命令并遮蔽后面的条目。
  ;;
  ;; ── 命令对照（你在界面上做的事 ↔ 条目里写的命令名）─────────────────────────
  ;;   按 M-x 输入命令             ↔ execute-extended-command
  ;;   打开文件                    ↔ find-file
  ;;   在项目里找文件／目录         ↔ project-find-file／project-find-dir
  ;;   切换项目／切换项目内缓冲区   ↔ project-switch-project／project-switch-to-buffer
  ;;   在当前缓冲区里按行搜索       ↔ consult-line
  ;;   在项目里全文搜索（ripgrep）  ↔ consult-ripgrep
  ;;   切换缓冲区（带预览）         ↔ consult-buffer
  ;;   跳到标题／符号／行号         ↔ consult-outline／consult-imenu／consult-goto-line
  ;;   不确定某个操作的命令名时：先执行一次，再按 C-h l 查看最近按键与实际执行的命令。
  ;; 插件默认 nil：不对任何命令做特殊设置；以下为本配置选择，可照样式增删改。
  (vertico-multiform-commands
   '(;; ═══ 例 1（已启用）：ripgrep 项目内全文搜索 ═══
     ;; 只匹配 consult-ripgrep 这一个命令，并同时设两项：位置放在底部居中，宽度设为 120 列
     ;; （搜索结果行较长）。它必须写在例 2 之前，否则会先被例 2 匹配，宽度设置就不生效。
     ("^consult-ripgrep$"
      (vertico-posframe-poshandler . posframe-poshandler-frame-bottom-center)
      (vertico-posframe-width . 120))
     ;; ═══ 例 2（已启用）：会在背景里实时预览的一组命令 ═══
     ;; 一次匹配多个命令：行搜索、大纲、符号、标记、跳转行号、切换缓冲区。
     ;; 这些命令选中候选时，背景缓冲区会跳到对应位置预览，所以悬浮窗放到底部，留出上方。
     ;; 想靠上就把位置改成 posframe-poshandler-frame-top-center；
     ;; 想只贴着当前窗口底部（分屏时不盖住其他窗口）用 posframe-poshandler-window-bottom-center。
     ("^consult-\\(line\\|line-multi\\|outline\\|imenu\\|imenu-multi\\|mark\\|global-mark\\|goto-line\\|buffer\\)$"
      (vertico-posframe-poshandler . posframe-poshandler-frame-bottom-center))
     ;; ═══ 例 3（模板，未启用）：让“M-x 输入命令”单独换位置 ═══
     ;; execute-extended-command 就是 M-x 调用的命令。启用方法：删掉下面两行开头的 ";; "。
     ;; 例子里的位置是正中；想要别的位置，改最后一行的位置函数。
     ;; 没有这一条时，M-x 使用全局位置（当前为底部居中）。
     ;; ("^execute-extended-command$"
     ;;  (vertico-posframe-poshandler . posframe-poshandler-frame-center))
     ;; ═══ 例 4（模板，未启用）：让“打开文件／项目内找文件、切换项目”靠上 ═══
     ;; 括号里是五个命令：find-file（打开文件）、project-find-file（项目内找文件）、
     ;; project-find-dir（项目内找目录）、project-switch-project（切换项目）、
     ;; project-switch-to-buffer（项目内切换缓冲区）。想增减命令，改括号里的名字，
     ;; 用 \\| 隔开，例如再加 \\|project-dired。启用方法：删掉下面两行开头的 ";; "。
     ;; ("^\\(find-file\\|project-find-file\\|project-find-dir\\|project-switch-project\\|project-switch-to-buffer\\)$"
     ;;  (vertico-posframe-poshandler . posframe-poshandler-frame-top-center))
     ))
  ;; 按补全类别设置，优先级低于上面的按命令设置。插件默认 nil；本配置不按类别区分。
  ;; 例如 ((file (vertico-posframe-poshandler . posframe-poshandler-frame-top-center))) 可让所有文件选择靠上显示。
  (vertico-multiform-categories nil)
  :config
  ;; 全局启用；它只在命令命中上面的列表时才改变设置，不命中时不产生影响。
  (vertico-multiform-mode 1))

;;; 匹配规则：普通候选使用 Orderless，文件保留基础匹配和部分路径补全。
(use-package orderless
  :demand t  ; 启动时加载匹配样式，确保第一次打开候选界面时已经可用。
  :custom
  ;; 本配置的普通补全顺序：先多关键词匹配，再尝试 basic；不是 Emacs 原始默认值。
  (completion-styles '(orderless basic))
  ;; 清除类别自带的默认样式，避免覆盖上面的统一规则；nil 不是关闭补全。
  (completion-category-defaults nil)
  ;; 文件类别单独处理：basic 优先兼容路径／TRAMP，partial-completion 支持部分路径。
  (completion-category-overrides '((file (styles basic partial-completion))))
  ;; Orderless 1.8 默认：每个关键词可按字面或正则匹配；只保留 orderless-literal 可禁用正则。
  (orderless-matching-styles '(orderless-literal orderless-regexp)))

;;; 候选注释：使用内置注释器，不增加自定义类别或切换键。
(use-package marginalia
  :custom
  (marginalia-align 'left)   ; 默认 left：注释左对齐；也可选 center 或 right。
  (marginalia-align-offset 0) ; 默认 0：注释对齐的额外偏移列数；增大可增加间距。
  :init
  (marginalia-mode 1))      ; 启动时启用候选注释；不需要每个缓冲区分别开启。

;;; 搜索与选择命令：首次调用时加载，保留插件默认预览策略。
(use-package consult
  ;; :commands 声明自动加载入口，不执行这些命令，也不定义快捷键。
  ;; 声明缓冲区选择、搜索、结构索引及附加导航菜单使用的命令。
  ;; 首次调用其中任意一个才加载插件；启动时不必加载整套搜索实现。
  :commands (consult-buffer consult-line consult-ripgrep consult-imenu
             consult-line-multi consult-imenu-multi consult-outline
             consult-goto-line consult-mark consult-global-mark
             consult-bookmark consult-yank-pop)
  :custom
  ;; 默认 any：选中候选变化时自动预览；nil 关闭预览，"M-." 改为按该键手动预览。
  (consult-preview-key 'any)
  ;; 默认 3 个字符才启动异步外部搜索；可改为 2，小值更早搜索但更容易产生大量结果。
  ;; 仅影响 consult-ripgrep 等异步命令，不限制 consult-line 的本地筛选。
  (consult-async-min-input 3))

(use-package embark
  ;; :commands 建立交互命令的自动加载入口，第一次使用时再加载主包。
  ;; 自定义按键只在文末 General 章节绑定；不改默认动作表和目标识别器。
  :commands (embark-act embark-dwim embark-act-all embark-become
             embark-collect embark-live embark-export embark-bindings)
  :custom
  ;; 默认用动作键位菜单；改为 embark-completing-read-prompter 可按命令名补全动作。
  (embark-prompter 'embark-keymap-prompter)
  ;; 默认 t：在 minibuffer 执行动作后退出候选会话；nil 则保留会话。
  ;; C-u C-. 可临时反转；动作菜单 q 也可切换，本轮保持默认。
  (embark-quit-after-action t)
  ;; 默认 t：对一组候选执行动作前询问确认；不关闭动作自身的确认机制。
  (embark-confirm-act-all t)
  ;; 默认 0.5 秒：进入动作菜单后，先显示简短目标提示，再弹出详细英文菜单。
  ;; 可改为 0 立即显示，或改为 1.0 延后；这不是进入菜单前的入口提醒。
  (embark-mixed-indicator-delay 0.5)
  ;; 默认 C-h：动作菜单内立即用补全选择动作；nil 关闭此帮助入口。
  (embark-help-key "C-h")
  ;; 默认 nil：用 embark-act 的全局按键循环切换目标；当前即再次按 C-.。
  ;; 可改成独立按键字符串；保持 nil 可随全局入口自动变化。
  (embark-cycle-key nil)
  ;; 默认 nil：不隐藏详细菜单里的任何动作；保留完整默认动作清单。
  (embark-verbose-indicator-excluded-actions nil)
  ;; 默认 t：分层显示子菜单，按前缀后显示该层动作；nil 将完整按键序列平铺显示。
  (embark-verbose-indicator-nested t))

(use-package embark-consult
  ;; :after 等待两个主包都加载；:demand t 随后立即加载桥接代码，
  ;; 避免已有 Consult 结果进入 Embark 时缺少导出器和目标转换。
  :after (embark consult)
  :demand t)

;;; 本机状态目录：供项目、历史、位置与恢复记录共同使用。
(defconst my/state-directory (expand-file-name ".cache/" my/config-directory)
  "保存本机 Emacs 状态文件的目录。")
(dolist (directory '("" "auto-save/" "auto-save-list/" "backups/"))
  (make-directory (expand-file-name directory my/state-directory) t))

(use-package project
  :ensure nil                         ; 内置 project.el，不从软件源安装。
  :demand t                           ; 尽早设置项目列表位置，再读取已有记录。
  :custom
  ;; 自定义存放位置；不改项目识别函数，也不新增固定项目路径。
  (project-list-file (expand-file-name "projects.eld" my/state-directory))
  ;; 选择项目后的中文操作菜单；第三项为明确的选择键，不依赖默认 keymap 推导。
  (project-switch-commands
   '((project-find-file "查找文件" ?f)
     (project-switch-to-buffer "切换缓冲区" ?b)
     (project-dired "项目根目录" ?d)
     (project-find-dir "查找子目录" ?D))))

(use-package recentf
  :ensure nil
  ;; 内置 recentf 不需要下载；:custom 只修改记录位置、数量和清理策略。
  :custom
  (recentf-save-file (expand-file-name "recentf.eld" my/state-directory))
  (recentf-max-saved-items 25)         ; 本机默认 25：退出后保留的最近文件上限，可增大。
  (recentf-max-menu-items 50)          ; 默认 10：recentf 菜单（File → Open Recent）里显示的条数，本配置选择 50。
                                       ; 它只管菜单；Dashboard 的最近文件条数另在 dashboard-items 里设置。
  (recentf-auto-cleanup 'mode)         ; 默认 mode：启用时清理失效项；never 为不自动清理。
  :config
  (recentf-mode 1))                   ; 记录最近文件；不意味着自动重新打开它们。

(use-package savehist
  :ensure nil
  ;; 内置 savehist 不需要下载；这里只保存支持历史的 minibuffer 输入。
  :custom
  (savehist-file (expand-file-name "history" my/state-directory))
  (savehist-autosave-interval 300)     ; 默认 300 秒保存历史；nil 关闭定时保存。
  (savehist-additional-variables nil) ; 默认 nil：不额外保存 kill ring 等变量。
  :config
  (savehist-mode 1))                  ; 保存支持历史记录的 minibuffer 输入，正常退出也会保存。

(use-package saveplace
  :ensure nil
  ;; 内置 saveplace 不需要下载；只记录文件阅读位置，不记录完整窗口布局。
  :custom
  (save-place-file (expand-file-name "places.eld" my/state-directory))
  :config
  (save-place-mode 1))                ; 记住文件中的阅读位置，不恢复完整窗口布局。

;;; 自动写回范围：本地可写文本，排除外部修改和需要交互加密的文件。
(defun my/auto-save-visited-p ()
  "判断当前缓冲区是否允许自动保存。"
  (and buffer-file-name
       (not (file-remote-p buffer-file-name))
       (not buffer-read-only)
       ;; text-mode 覆盖笔记／文档，prog-mode 覆盖源码和配置模式；不按扩展名白名单限制。
       (derived-mode-p 'text-mode 'prog-mode)
       ;; 排除以二进制 no-conversion 编码访问的文件。
       (not (eq (coding-system-base buffer-file-coding-system) 'no-conversion))
       (not (string-match-p "\\.gpg\\'" (downcase buffer-file-name)))
       (not (eq (find-file-name-handler buffer-file-name 'write-region) 'epa-file-handler))
       (not (bound-and-true-p epa-file-encrypt-to))
       ;; 新文件要求父目录存在；已存在文件被外部修改／删除时跳过，不静默覆盖或重建。
       (file-directory-p (file-name-directory buffer-file-name))
       (file-writable-p buffer-file-name)
       (or (file-exists-p buffer-file-name)
           (equal (visited-file-modtime) -1))
       (verify-visited-file-modtime (current-buffer))))

(use-package files
  :ensure nil
  ;; 内置 files 提供自动保存变量；:custom 控制间隔、筛选函数和备份文件策略。
  :custom
  (auto-save-visited-interval 5)        ; 默认 5 秒，可改为 10；是 Emacs 空闲时间。
  (auto-save-visited-predicate #'my/auto-save-visited-p) ; 自定义范围，默认 nil 不额外筛选。
  (remote-file-name-inhibit-auto-save-visited t) ; 本配置排除远程文件；Emacs 默认 nil。
  ;; 默认 t，本配置显式开启：保存已有文件时，按 Emacs 原生规则保留保存前的磁盘内容。
  ;; 备份集中在下方 backup-directory-alist 指定的 .cache/backups/，不在原文件旁生成 file~。
  ;; 这不是每次保存都新增一个版本；通常每次访问文件后的首次符合条件的保存会创建备份。
  ;; 改为 nil 可关闭保存前备份，不影响独立的 #文件# 自动保存恢复副本。
  (make-backup-files t)
  :config
  (auto-save-visited-mode 1))

(use-package autorevert
  :ensure nil
  ;; 内置 autorevert 提供外部修改检测；:custom 控制轮询、文件通知和远程文件范围。
  :custom
  (auto-revert-interval 5)                    ; 默认 5 秒轮询；文件通知可能更早触发。
  (auto-revert-use-notify t)                  ; 默认 t：支持时使用文件通知，保留轮询兜底。
  (auto-revert-remote-files nil)              ; 默认 nil：不自动刷新远程文件。
  (global-auto-revert-non-file-buffers nil)   ; 默认 nil：不全局刷新 Dired 等非文件界面。
  :config
  (global-auto-revert-mode 1))                ; 未修改文件可刷新；不强制替换未保存编辑。

;; 默认 backup-directory-alist=nil：备份通常留在原文件旁；本配置指定集中目录。
;; "." 匹配文件名，Emacs 为集中存放的备份编码原路径，避免不同目录同名文件互相覆盖。
;; 目录在前面的状态目录章节创建；路径基于配置根目录，不依赖 HOME 或启动工作目录。
;; 上面的 make-backup-files=t 负责开启；这里仅指定写入位置，不改变备份频率或版本数量。
;; 反引号 ` 构造列表，逗号 , 让 expand-file-name 先算出本机绝对目录。
;; 不同原路径的备份文件名可能含 ! 等编码字符，这是集中目录下避免重名的正常命名。
(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups/" my/state-directory))))

;;; 仅追加本地文件转换：保留原有远程转换及加密文件处理器的行为。
(add-to-list 'auto-save-file-name-transforms
             (list "\\`.*\\'"
                   (expand-file-name "auto-save/" my/state-directory)
                   'sha256)
             t) ; 追加到现有规则之后，原有远程规则先匹配；加密处理器优先于转换表。
;; 默认恢复副本机制保持开启，路径使用哈希防止同名文件冲突和 Windows 长文件名问题。
(setq auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" my/state-directory))

;;; Dashboard：复用已有历史与项目数据；不安装额外的项目管理插件。
;; 横幅图片目录：把图片放进来，每次启动随机选一张；改成别的目录就换图库。
(defvar my/dashboard-banner-directory (expand-file-name "assets/dashboard/" my/config-directory)
  "存放 Dashboard 横幅图片的目录；启动时随机选一张，没有图片则使用插件自带横幅。")
(make-directory my/dashboard-banner-directory t)

;; 启动时抽签一次：插件自带的“列表随机”每次重绘都重新抽，窗口大小变化会让横幅突然换图。
(defvar my/dashboard-banner
  (let ((case-fold-search t))           ; 扩展名不区分大小写
    (let ((files (seq-filter
                  (lambda (file) (string-match-p "\\.\\(png\\|jpe?g\\|gif\\|webp\\|svg\\|xbm\\)\\'" file))
                  (directory-files my/dashboard-banner-directory t))))
      (if files (seq-random-elt files) 'official)))
  "本次启动选中的横幅：目录里的某张图片，或回退的 official。")

;; 图片优化：把大图缩成横幅用的小 jpg，需要 ImageMagick 的 magick 命令。
;; 不使用 convert：Windows 自带的 convert.exe 是磁盘格式转换工具，不是 ImageMagick。
(defvar my/dashboard-banner-height 300
  "优化后横幅图片的高度（像素）；略大于显示用的 250，缩放后不容易糊。")
(defvar my/dashboard-banner-quality 85
  "优化后 jpg 的压缩质量，1 到 100；越大越清晰，文件也越大。")
(defvar my/image-magick-program nil
  "magick 可执行文件的完整路径；nil 表示自动查找，找不到时在这里写完整路径。")

(defun my/find-magick ()
  "返回 magick 的路径：先用设置的变量，再查 PATH，最后找 Emacs 自己所在的目录。"
  (or my/image-magick-program
      (executable-find "magick")
      ;; MSYS2 版 Emacs 和 ImageMagick 常装在同一个 bin 目录；从资源管理器启动时 PATH 里可能没有它。
      (let ((exec-path (cons invocation-directory exec-path)))
        (executable-find "magick"))
      (user-error "找不到 ImageMagick 的 magick 命令：先安装 ImageMagick；已安装就在主 Org 的 Dashboard 一节把 my/image-magick-program 设为 magick.exe 的完整路径（保存、tangle、重启），临时可 M-x set-variable RET my/image-magick-program RET")))

(defun liyunfeng/optimize-dashboard-banners ()
  "把横幅目录里的大图缩成小 jpg（名称加 .opt），成功后直接删除原图。只处理横幅目录，不能指定别的目录；执行前确认一次，y 开始，n 或 C-g 取消；需要 ImageMagick。"
  (interactive)
  (let* ((magick (my/find-magick))
         (case-fold-search t)           ; 扩展名不区分大小写
         (dir (file-name-as-directory (expand-file-name my/dashboard-banner-directory)))
         (todo nil) (done 0) (skipped 0) (failed 0))
    ;; 先只统计，不改动任何文件。
    (dolist (file (directory-files dir t))
      (when (and (file-regular-p file)
                 (string-match-p "\\.\\(png\\|jpe?g\\|webp\\)\\'" file))
        (let ((name (file-name-sans-extension (file-name-nondirectory file))))
          (if (or (string-match-p "\\.opt\\'" name)
                  (file-exists-p (expand-file-name (concat name ".opt.jpg") dir)))
              (setq skipped (1+ skipped)) ; 已是优化结果，或同名结果已存在
            (push file todo)))))
    (cond
     ((null todo)
      (message "没有需要优化的图片：已跳过 %d 张（已优化或同名结果已存在）" skipped))
     ((not (y-or-n-p (format "优化 %d 张图片并直接删除原图（不可恢复），继续吗？" (length todo))))
      (message "已取消，没有改动任何文件"))
     (t
      (dolist (file (nreverse todo))
        (let ((out (expand-file-name
                    (concat (file-name-sans-extension (file-name-nondirectory file)) ".opt.jpg") dir)))
          (if (file-exists-p out)
              ;; 同名不同扩展（如 a.jpg 与 a.png）会得到同一个结果名：第二张保留原图，不覆盖。
              (setq skipped (1+ skipped))
            (with-temp-buffer
              (if (and (zerop (call-process
                               magick nil t nil
                               (concat (convert-standard-filename file) "[0]") ; [0] 只取第一帧
                               "-auto-orient"
                               "-background" "white" "-alpha" "remove" "-alpha" "off" ; 透明部分铺白，jpg 不支持透明
                               "-resize" (format "x%d>" my/dashboard-banner-height)   ; 只缩小，不放大
                               "-strip" "-quality" (number-to-string my/dashboard-banner-quality)
                               (convert-standard-filename out)))
                       (> (or (file-attribute-size (file-attributes out)) 0) 0))
                  (progn
                    (delete-file file)  ; 结果确认生成后才删除原图
                    (setq done (1+ done)))
                (setq failed (1+ failed))
                (when (file-exists-p out) (delete-file out))
                (message "优化失败（原图保留）%s：%s" file (string-trim (buffer-string))))))))
      (message "横幅图片优化完成：处理 %d 张，跳过 %d 张，失败 %d 张%s"
               done skipped failed (if (> done 0) "；下次启动生效" ""))))))

(defun liyunfeng/dashboard-on-startup ()
  "无文件的普通启动完成后打开 Dashboard，不抢占已打开的文件。"
  (unless (or (daemonp)
              (seq-some (lambda (buffer)
                          (buffer-local-value 'buffer-file-name buffer))
                        (buffer-list)))
    (dashboard-open)))

(use-package dashboard
  :demand t                           ; 启动时加载并注册入口；安装仍由 use-package 处理。
  :custom
  ;; 插件默认 *dashboard*；本配置沿用参考名称，影响缓冲区切换时的显示名称。
  (dashboard-buffer-name "*my dashboard*")
  ;; 上游默认 Welcome to Emacs!；本配置沿用参考标题，可改为自己的短句。
  (dashboard-banner-logo-title "Have a nice day!")
  ;; 插件默认 official；本配置使用上面启动时随机选出的图片，目录为空时就是 official。
  (dashboard-startup-banner my/dashboard-banner)
  ;; 插件默认 0（不限制）；横幅图片最高 250 像素，大图等比缩小。官方横幅 250×215，不受影响。
  (dashboard-image-banner-max-height 250)
  ;; 两项默认均 nil；本配置沿用参考开启水平和垂直居中。
  (dashboard-center-content t)
  (dashboard-vertically-center-content t)
  ;; 默认 nil；本配置 t：章节前后导航到首尾时循环，不改变文件列表本身的顺序。
  (dashboard-navigation-cycle t)
  ;; 默认 20，本配置保持；各项指定数量优先于此兜底数量，nil 表示不限制。
  (dashboard-items-default-length 20)
  ;; 默认最近文件／书签／日程各 5；本配置沿用参考，空数据源不会凭空产生条目。
  (dashboard-items '((recents . 10) (bookmarks . 5) (projects . 5)
                     (agenda . 3) (registers . 3)))
  ;; 默认 project-el，本配置保持，与现有 project.el 共用已知项目。
  (dashboard-projects-backend 'project-el)
  ;; 默认 nil：使用后端自带项目切换逻辑；不替换为 Projectile/Counsel 命令。
  (dashboard-projects-switch-function nil)
  ;; 默认 t：显示未来一周的日程；改为 nil 只看当天，数据来自 org-agenda-files。
  (dashboard-week-agenda t)
  ;; 默认 nil：保留上游栏目标题；下方导航按钮另使用中文。
  (dashboard-item-names nil)
  ;; 两项默认 nil；本配置选择 t，显示栏目图标与文件图标。
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  ;; 上游默认 #'display-graphic-p（只在图形界面显示）；本配置选择 t：图形和终端都显示。
  ;; 终端里能否显示取决于终端字体；出现方框就改回 #'display-graphic-p。
  (dashboard-display-icons-p t)
  ;; 插件默认 all-the-icons；本配置使用 nerd-icons。
  (dashboard-icon-type 'nerd-icons)
  ;; nerd-icons-scale-factor 会再乘一遍下面的高度，图标比字符格子还大，右侧和下侧就会被裁掉。
  ;; 所以这里除以同一个倍数抵消：最终大小 = 倍数 × (1 ÷ 倍数) × 插件默认高度，即回到插件原本的大小。
  ;; 想让 Dashboard 的图标比原来大一点，把除法前的 1.0 / 1.2 改大，例如 1.1；出现裁切就改回去。
  ;; 插件默认：最近文件等条目图标高度 1.0、栏目标题图标高度 1.2；垂直微调 -0.05 / 0.0。
  ;;;(dashboard-icon-file-height (/ 1.0 nerd-icons-scale-factor))
  ;;;(dashboard-icon-file-v-adjust (/ -0.05 nerd-icons-scale-factor))
  ;;;(dashboard-heading-icon-height (/ 1.2 nerd-icons-scale-factor))
  ;; 保持插件默认的统计函数：显示启动耗时与包数量，不等于独立性能分析。
  (dashboard-init-info #'dashboard-init--info)
  ;; 上游默认布局没有 navigator；本配置显式插入，保留启动统计与页脚。
  (dashboard-startupify-list '(dashboard-insert-banner dashboard-insert-newline
                              dashboard-insert-banner-title dashboard-insert-newline
                              dashboard-insert-navigator dashboard-insert-newline
                              dashboard-insert-init-info dashboard-insert-items
                              dashboard-insert-newline dashboard-insert-footer))
  ;; 默认 nil；格式为每行一个按钮列表，各按钮依次为图标、标题、帮助、动作。
  ;; 动作使用已有命令的交互入口，保留路径／项目选择与取消流程。
  (dashboard-navigator-buttons
   '((("" "打开文件" "选择文件并打开"
       (lambda (&rest _) (call-interactively #'find-file)))
      ("" "切换项目" "选择 project.el 已知项目"
       (lambda (&rest _) (call-interactively #'project-switch-project)))
      ("" "个人配置" "从 org_configs 选择配置源文件"
       (lambda (&rest _) (call-interactively #'liyunfeng/find-config-source))))))
  :config
  ;; 不使用 dashboard-setup-startup-hook：它会跳过带 --init-directory 等参数的启动。
  (add-hook 'emacs-startup-hook #'liyunfeng/dashboard-on-startup)
  ;; 窗口大小改变时重新排版，沿用插件提供的函数，不执行整个初始化流程。
  (add-hook 'window-size-change-functions #'dashboard-resize-on-hook))

(use-package rainbow-delimiters
  ;; :hook 创建自动加载入口；进入 prog-mode 及其派生编程模式时才加载并开启。
  ;; Org 主模式不属于 prog-mode，编辑 Lisp 代码块时可用 C-c ' 进入对应编程模式。
  :hook (prog-mode . rainbow-delimiters-mode)
  :custom
  ;; 插件默认 9，本配置保持：使用九种深度颜色，超过后循环；可调小减少颜色种类。
  (rainbow-delimiters-max-face-count 9)
  ;; 插件默认 0，本配置保持：不为外层保留专用颜色；须小于上面的颜色数量。
  ;; 例如改为 1，可让最外层颜色不参与更深层的循环。
  (rainbow-delimiters-outermost-only-face-count 0))

;;; Transient：Magit 等工具的参数菜单；本机 Emacs 已内置，Magit 的依赖检查仍照常进行。
(use-package transient
  :ensure nil
  ;; Transient 是 Emacs 内置的参数菜单；:defer t 不主动加载，Magit 调用时再加载。
  :defer t                           ; 只先设置状态位置；由 Magit 等调用者按需加载。
  :init
  ;; 插件默认写入 user-emacs-directory 下的 transient/；本配置统一放入 .cache/。
  ;; 在本配置首次调用 Magit 前设置；不迁移、删除或覆盖原目录中的已有状态。
  (setq transient-levels-file (expand-file-name "transient/levels.el" my/state-directory)
        transient-values-file (expand-file-name "transient/values.el" my/state-directory)
        transient-history-file (expand-file-name "transient/history.el" my/state-directory)))

;;; Magit：用命令列表创建自动加载入口，使用 Git 操作时才加载完整界面。
(use-package magit
  ;; :commands 只建立 Git 交互命令的自动加载入口；调用命令时才加载 Magit。
  :commands (magit-status magit-dispatch magit-file-dispatch
             magit-diff magit-log magit-log-buffer-file
             magit-stage-files magit-unstage-files magit-commit
             magit-fetch magit-pull magit-push magit-remote
             magit-branch magit-merge magit-rebase magit-stash magit-tag magit-worktree))
;; 不改 Git 身份、认证、签名、提交模板或 Transient 的提交参数默认值。
;; -s / --signoff 由用户在提交菜单选择；-S / --gpg-sign 是不同的签名选项。

;;; diff-hl：启动时启用全局模式，仅在适用的受版本控制文件中显示修改标记。
(use-package diff-hl
  :demand t                           ; 文件打开后即可显示标记，不必先打开 Magit。
  :custom
  ;; 默认 left：标记放在窗口左侧；改为 right 可移到右侧。
  (diff-hl-side 'left)
  ;; 默认 t：Git 标记包含已暂存但尚未提交的修改；nil 改为以暂存区作为比较基准。
  ;; 当前保留 t，暂存后仍可看见修改，提交后再随刷新消失。
  (diff-hl-show-staged-changes t)
  ;; 默认 t：终端没有 fringe 时自动使用 margin，并在需要时提供一列宽度。
  ;; 保持默认的图形 fringe / 终端 margin 切换，不全局强制 margin 模式。
  (diff-hl-fallback-to-margin t)
  :config
  (global-diff-hl-mode 1)
  ;; 默认在保存后更新；本配置不启用 flydiff，不在每次输入时定时计算差异。
  ;; Magit 修改暂存区或提交并刷新后同步标记；无需旧的 pre-refresh 钩子。
  ;; Magit 刷新结束后调用 diff-hl 的同步函数，让文件旁的修改标记跟随仓库状态更新。
  ;; 这里只登记回调，不会立即打开或刷新 Magit，也不会执行暂存、提交等 Git 操作。
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh))

;;; 帮助增强：调用时加载 Helpful，安装由 use-package 处理。
;; 实际按键在末尾统一绑定，不在这里覆盖任何模式键位。
(use-package helpful
  ;; :commands 只建立 M-x 自动加载入口；不启动后台模式，也不覆盖原生帮助键。
  :commands (helpful-key helpful-callable helpful-command
             helpful-variable helpful-at-point))

;;; 前缀按键提示：输入 leader 后稍等，显示下一步可用命令。
(use-package which-key
  ;; :ensure nil 使用 Emacs 内置 which-key；:demand t 启动时立即显示前缀提示。
  :ensure nil
  :demand t
  :custom
  (which-key-idle-delay 0.5)
  :config
  (which-key-mode 1))

;;; 窗口配置历史：内置 Winner 记录布局历史；最大化切换另存 Frame 布局。
(use-package winner
  ;; :ensure nil 使用内置 Winner；:demand t 立即记录窗口布局历史。
  :ensure nil
  :demand t
  :config
  (winner-mode 1))

;;; 启动统计：只记录一次快照，不改变垃圾回收策略。
(defvar liyunfeng/startup-statistics nil
  "首次报告时保存的初始化秒数、进程累计 GC 次数和 GC 秒数。")

(defun liyunfeng/display-startup-time ()
  "显示初始化耗时与启动报告时的 GC 快照，不重复累加运行期数据。"
  (interactive)
  (unless liyunfeng/startup-statistics
    (unless (and before-init-time after-init-time)
      (user-error "Initialization has not finished"))
    (setq liyunfeng/startup-statistics
          (list (float-time (time-subtract after-init-time before-init-time))
                gcs-done gc-elapsed)))
  (message "初始化耗时 %.2f 秒；启动报告时累计 GC %d 次，GC 耗时 %.2f 秒。"
           (nth 0 liyunfeng/startup-statistics)
           (nth 1 liyunfeng/startup-statistics)
           (nth 2 liyunfeng/startup-statistics)))

;; t 表示追加到现有启动 hook 后面；只输出统计，不切换缓冲区或重新加载配置。
(add-hook 'emacs-startup-hook #'liyunfeng/display-startup-time t)

;;; 窗口布局与文件辅助命令；Org 生成和目录更新直接使用原生命令。
;; 窗口最大化：布局保存在当前 Frame 参数中，各 Frame 互不干扰。
(defun my/toggle-window-maximize ()
  "在当前窗口布局和单窗口显示之间切换。"
  (interactive)
  (let ((saved (frame-parameter nil 'my/window-configuration)))
    (if (window-configuration-p saved)
        (progn
          (set-window-configuration saved)
          (set-frame-parameter nil 'my/window-configuration nil))
      (unless (one-window-p)
        (let ((configuration (current-window-configuration)))
          (delete-other-windows)
          (set-frame-parameter nil 'my/window-configuration configuration))))))

;; 只复制当前文件的绝对路径，不修改文件；无文件的缓冲区会明确提示。
(defun my/copy-file-path ()
  "把当前文件的绝对路径复制到 kill ring。"
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (let ((path (expand-file-name buffer-file-name)))
    (kill-new path)
    (message "Copied: %s" path)))

;; 这四个配置维护命令统一使用 liyunfeng/ 前缀；(interactive) 让它们出现在 M-x 候选中。
;; 文档字符串首行供 Marginalia 展示用途；保留内置命令及前缀参数语义。
(defun liyunfeng/set-variable ()
  "临时修改用户选项，不自动写回 Org 配置。输入变量名和 Lisp 值，RET 确认，C-g 取消；原样传递前缀参数给 set-variable。"
  (interactive)
  (call-interactively #'set-variable))

(defun liyunfeng/eval-last-sexp ()
  "执行光标前的 Lisp 表达式，默认在底部显示结果。保留 eval-last-sexp 的前缀参数行为；如带 C-u，结果会插入正文。"
  (interactive)
  (call-interactively #'eval-last-sexp))

;; 只固定配置源目录，不固定 Org 文件名；文件改名后仍从候选中选择。
(defun liyunfeng/find-config-source ()
  "从 org_configs 选择配置源文件，不生成或加载配置。选择当前主 Org 并 RET 打开，C-g 取消；不依赖固定 Org 文件名。"
  (interactive)
  (let ((default-directory (expand-file-name "org_configs/" my/config-directory)))
    (unless (file-directory-p default-directory)
      (user-error "Config source directory not found: %s" default-directory))
    (call-interactively #'find-file)))

;; 直接传递 C-u 对应的原始前缀值，避免键盘宏受 Evil 的 C-u 绑定影响。
(defun liyunfeng/eval-last-sexp-insert-result ()
  "执行光标前的 Lisp 表达式，并将结果插入正文。等同于 eval-last-sexp 带 C-u 前缀；需把光标放在表达式之后，误插入可撤销。"
  (interactive)
  (let ((current-prefix-arg '(4)))
    (call-interactively #'eval-last-sexp)))

;;; 统一键位：General 管理绑定，which-key 显示随 keymap 保存的中文描述。
(use-package general
  ;; :after 等待 Evil；:demand t 立即创建统一 leader keymap，后面的绑定才会生效。
  :after evil
  :demand t
  :config
  (defvar my/leader-map (make-sparse-keymap))
  (defvar my/command-map (make-sparse-keymap))
  (defvar my/file-map (make-sparse-keymap))
  (defvar my/buffer-map (make-sparse-keymap))
  (defvar my/help-map (make-sparse-keymap))
  (defvar my/diagnostic-map (make-sparse-keymap))
  (defvar my/window-map (make-sparse-keymap))
  (defvar my/quit-map (make-sparse-keymap))
  (defvar my/org-map (make-sparse-keymap))
  (defvar my/jump-map (make-sparse-keymap))
  (defvar my/search-map (make-sparse-keymap))
  (defvar my/project-map (make-sparse-keymap))
  (defvar my/edit-map (make-sparse-keymap))
  (defvar my/git-map (make-sparse-keymap))
  (defvar my/git-view-map (make-sparse-keymap))
  (defvar my/git-commit-map (make-sparse-keymap))
  (defvar my/git-remote-map (make-sparse-keymap))
  (defvar my/git-branch-map (make-sparse-keymap))
  (defvar my/git-hunk-map (make-sparse-keymap))

  (general-def my/file-map
    "f" '("打开文件" . find-file)                  ; Find file，打开文件
    "s" '("保存文件" . save-buffer)                ; Save，保存
    "a" '("另存为" . write-file)                   ; Save as，另存为
    "d" '("目录管理" . dired)                      ; Dired，目录管理
    ;; 保留内置确认：不要用无提示覆盖方式重新读取有未保存修改的文件。
    "u" '("重新读取文件" . revert-buffer)          ; Update from disk，重新读取磁盘内容
    "p" '("复制文件完整路径" . my/copy-file-path)  ; Path，文件完整路径
    "S" '("保存多个文件" . save-some-buffers)      ; Save all，保留保存询问
    "R" '("恢复文件内容" . recover-file)           ; Recover，读取恢复副本
    "m" '("设置文件书签" . bookmark-set)           ; Mark，命名文件位置
    "b" '("选择书签" . consult-bookmark))          ; Bookmark，预览与跳转

  (general-def my/buffer-map
    "b" '("切换与预览缓冲区" . consult-buffer)        ; Buffer，选择与预览缓冲区
    "i" '("缓冲区列表" . ibuffer)                     ; Ibuffer，缓冲区管理列表
    "k" '("关闭当前缓冲区" . kill-current-buffer)     ; Kill，关闭缓冲区
    "n" '("下一个缓冲区" . next-buffer)               ; Next，下一个
    "p" '("上一个缓冲区" . previous-buffer)           ; Previous，上一个
    "o" '("返回上个缓冲区" . mode-line-other-buffer)  ; Other，返回最近缓冲区
    "r" '("只读开关" . read-only-mode))               ; Read only，缓冲区只读开关

  (general-def my/help-map
    "k" '("解释按键" . helpful-key)                          ; Key，按键帮助
    "f" '("函数帮助" . helpful-callable)                     ; Function，函数帮助
    "x" '("命令帮助" . helpful-command)                      ; Execute，交互命令帮助
    "v" '("变量帮助" . helpful-variable)                     ; Variable，变量帮助
    "." '("光标处 Lisp 符号" . helpful-at-point)             ; At point，光标处符号
    "m" '("当前模式说明" . describe-mode)                    ; Mode，当前模式
    "l" '("当前模式按键" . which-key-show-major-mode)         ; Local，当前主模式按键
    "b" '("当前有效键位" . describe-bindings)                ; Bindings，有效键位
    "w" '("查找命令按键" . where-is)                         ; Where is，查找命令绑定
    "a" '("按名称找命令" . apropos-command)                  ; Apropos，按名称查找命令
    "i" '("Emacs 手册" . info-emacs-manual)                  ; Info，Emacs 手册
    "g" '("自定义键位清单" . general-describe-keybindings))  ; General，自定义键位

  ;; Diagnostics：诊断；Messages 和 Debug 各保留一个入口。
  (general-def my/diagnostic-map
    "m" '("查看消息" . view-echo-area-messages)  ; Messages，消息日志
    "d" '("错误回溯" . toggle-debug-on-error))   ; Debug，错误回溯开关

  ;; Window，窗口布局；关闭显示区域不关闭其中的 Buffer。
  (general-def my/window-map
    "h" '("左侧窗口" . windmove-left)                  ; Left，沿用 Vim 向左键
    "j" '("下方窗口" . windmove-down)                  ; Down，沿用 Vim 向下键
    "k" '("上方窗口" . windmove-up)                    ; Up，沿用 Vim 向上键
    "l" '("右侧窗口" . windmove-right)                 ; Right，沿用 Vim 向右键
    "c" '("关闭当前窗口" . delete-window)              ; Close，关闭窗口
    "w" '("下一个窗口" . other-window)                 ; Window，循环切换窗口
    "s" '("上下拆分" . split-window-below)             ; Split，上下拆分
    "v" '("左右拆分" . split-window-right)             ; Vertical split，左右拆分
    "o" '("保留当前窗口" . delete-other-windows)       ; Only，只保留当前窗口
    "m" '("最大化或恢复" . my/toggle-window-maximize)  ; Maximize，最大化或恢复
    "u" '("撤销布局变化" . winner-undo)                ; Undo，恢复窗口布局
    "r" '("重做布局变化" . winner-redo)                ; Redo，重做窗口布局
    "=" '("均衡窗口大小" . balance-windows))           ; Balance，均衡窗口大小

  ;; Quit：退出；Q 按用户选择提供强制退出，跳过常规保存询问。
  (general-def my/quit-map
    "q" '("退出当前窗口或会话" . evil-quit)             ; Quit，当前窗口或会话
    "a" '("退出终端会话" . save-buffers-kill-terminal)  ; All，检查保存后退出会话
    "Q" '("强制退出进程" . kill-emacs))                 ; Force quit，跳过常规保存询问

  ;; Org，文档与配置维护，保留标题与结构导航入口。
  ;; 标题跳转与代码块编辑在 Org 中调用；生成和目录更新使用原生命令。
  (general-def my/org-map
    "b" '("生成当前文档代码" . org-babel-tangle)             ; Babel，提取当前 Org 代码，不执行或加载
    "g" '("Org 标题跳转" . org-goto)                         ; Go to，跳转标题
    "i" '("当前文件结构索引" . consult-imenu)                ; Index，预览结构索引
    "t" '("更新当前文档目录" . toc-org-insert-toc)           ; Table of contents，当前文档目录
    "s" '("编辑 Org 代码块" . org-edit-special)              ; Special，专用编辑界面
    "TAB" '("切换当前折叠" . org-cycle)                      ; Cycle，按光标上下文循环
    "c" '("切换全文概览" . org-shifttab)                     ; Cycle all，全文大纲显示
    "u" '("上一级标题" . org-up-heading-safe)                ; Up，上级标题
    "n" '("下一同级标题" . org-forward-heading-same-level)   ; Next，下一个同级
    "p" '("上一同级标题" . org-backward-heading-same-level)  ; Previous，上一个同级
    "l" '("打开链接" . org-open-at-point))                   ; Link，打开光标处链接

  ;; Jump，当前窗口可见文字定位；字符输入后按标签选择。
  (general-def my/jump-map
    "j" '("字符标签跳转" . avy-goto-char-timer)  ; Jump，字符跳转
    "l" '("可见行跳转" . avy-goto-line)          ; Line，行跳转
    "c" '("单字符跳转" . avy-goto-char)          ; Character，单字符定位
    "w" '("单词起点跳转" . avy-goto-word-0)      ; Word，单词起点
    "W" '("按首字符跳词" . avy-goto-word-1)      ; Word initial，单词首字符
    "n" '("跳到行列位置" . consult-goto-line)    ; Number，行列位置
    "m" '("当前缓冲区标记" . consult-mark)       ; Mark，本地标记环
    "M" '("跨缓冲区标记" . consult-global-mark)  ; Global mark，全局标记环
    "b" '("返回 Avy 跳转前" . avy-pop-mark))     ; Back，返回 Avy 记录位置

  ;; Search，全文搜索与结构选择；项目搜索依赖 Emacs 能找到 rg。
  (general-def my/search-map
    "s" '("搜索当前缓冲区" . consult-line)             ; Search，搜索匹配行
    "r" '("项目或目录搜索" . consult-ripgrep)          ; Ripgrep，外部文本搜索
    "i" '("当前文件结构索引" . consult-imenu)          ; Index，预览结构索引
    "S" '("搜索多个缓冲区" . consult-line-multi)       ; Search buffers，搜索缓冲区内容
    "I" '("项目缓冲区结构索引" . consult-imenu-multi)  ; Index buffers，同模式项目索引
    "o" '("大纲标题" . consult-outline))               ; Outline，选择大纲标题

  ;; Project，项目管理；沿用内置确认，不固定项目路径或 shell。
  (general-def my/project-map
    "f" '("查找项目文件" . project-find-file)                  ; File，项目文件
    "p" '("切换项目" . project-switch-project)                 ; Project，选择项目
    "b" '("切换项目缓冲区" . project-switch-to-buffer)         ; Buffer，项目缓冲区
    "B" '("项目缓冲区列表" . project-list-buffers)             ; Buffer list，集中管理
    "d" '("项目根目录" . project-dired)                        ; Directory，根目录
    "D" '("查找项目子目录" . project-find-dir)                 ; Find directory，选择子目录
    "s" '("保存项目文件" . project-save-some-buffers)          ; Save，保留默认询问
    "k" '("关闭项目缓冲区" . project-kill-buffers)             ; Kill，关闭并检查保存
    "a" '("扫描并记住项目" . project-remember-projects-under)  ; Add，扫描项目
    "x" '("移除项目记录" . project-forget-project)             ; Exclude，仅移除记录
    "!" '("执行项目命令" . project-async-shell-command))       ; Command，默认 shell 异步命令

  (general-def my/edit-map
    "y" '("选择剪贴历史" . consult-yank-pop))  ; Yank，选择 kill ring 内容

  ;; Git，仓库操作：子菜单可从文件缓冲区直接调用，不必先进入状态页。
  (general-def my/git-view-map
    "d" '("查看差异" . magit-diff)                  ; Diff，差异菜单
    "l" '("查看提交日志" . magit-log)               ; Log，日志菜单
    "f" '("当前文件历史" . magit-log-buffer-file))  ; File log，文件提交记录

  (general-def my/git-commit-map
    "s" '("选择文件暂存" . magit-stage-files)        ; Stage，选择文件加入暂存区
    "u" '("选择文件取消暂存" . magit-unstage-files)  ; Unstage，保留工作区修改
    "c" '("提交菜单" . magit-commit))                ; Commit，选择参数与提交方式

  (general-def my/git-remote-map
    "f" '("抓取远端" . magit-fetch)    ; Fetch，更新远端跟踪引用
    "l" '("拉取并整合" . magit-pull)   ; Pull，选择整合方式
    "p" '("推送菜单" . magit-push)     ; Push，选择目标后执行
    "r" '("管理远端" . magit-remote))  ; Remote，管理远端地址

  (general-def my/git-branch-map
    "b" '("分支管理" . magit-branch)       ; Branch，创建与切换分支
    "m" '("合并菜单" . magit-merge)        ; Merge，合并分支
    "r" '("变基菜单" . magit-rebase)       ; Rebase，变基与继续操作
    "z" '("贮藏修改" . magit-stash)        ; Stash，贮藏与恢复修改
    "t" '("标签管理" . magit-tag)          ; Tag，标签操作
    "w" '("工作树管理" . magit-worktree))  ; Worktree，独立工作目录

  (general-def my/git-hunk-map
    "n" '("下一修改块" . diff-hl-next-hunk)      ; Next hunk，下一修改块
    "p" '("上一修改块" . diff-hl-previous-hunk)  ; Previous hunk，上一修改块
    "s" '("查看修改块" . diff-hl-show-hunk))     ; Show hunk，显示具体差异

  (general-def my/git-map
    "s" '("仓库状态" . magit-status)               ; Status，仓库状态页
    "g" '("Git 总菜单" . magit-dispatch)           ; Git dispatch，完整操作入口
    "f" '("当前文件操作" . magit-file-dispatch)    ; File dispatch，文件操作菜单
    "v" (cons "查看差异与历史" my/git-view-map)    ; View，查看差异与历史
    "c" (cons "暂存与提交" my/git-commit-map)      ; Commit，暂存与提交
    "r" (cons "远端同步" my/git-remote-map)        ; Remote，远端同步
    "b" (cons "分支与历史操作" my/git-branch-map)  ; Branch，分支与历史操作
    "h" (cons "修改块" my/git-hunk-map))           ; Hunk，修改块导航与查看

  ;; 根前缀是逗号，再经过两次逗号，得到 ,,,；M-x 本身仍可使用。
  (general-def my/command-map
    "," '("执行命令" . execute-extended-command))  ; Command，执行命令

  (general-def my/leader-map
    "," (cons "命令" my/command-map)     ; Command，命令
    "f" (cons "文件" my/file-map)        ; File，文件
    "b" (cons "缓冲区" my/buffer-map)    ; Buffer，缓冲区
    "h" (cons "帮助" my/help-map)        ; Help，帮助
    "d" (cons "诊断" my/diagnostic-map)  ; Diagnostics，诊断
    "w" (cons "窗口" my/window-map)      ; Window，窗口
    "q" (cons "退出" my/quit-map)        ; Quit，退出
    "o" (cons "文档与配置" my/org-map)   ; Org，文档与配置
    "j" (cons "跳转" my/jump-map)        ; Jump，屏幕内定位
    "s" (cons "搜索" my/search-map)      ; Search，搜索与索引
    "p" (cons "项目" my/project-map)     ; Project，项目管理
    "e" (cons "编辑" my/edit-map)        ; Edit，文本编辑
    "g" (cons "版本控制" my/git-map))    ; Git，版本控制

  ;; 普通／可视／motion 状态使用逗号；插入状态不占用逗号。
  ;; motion 覆盖一些只读工具界面；override 减少局部模式遮挡 leader。
  (general-define-key
   :states '(normal visual motion)
   :keymaps 'override
   "," my/leader-map)

  ;; 普通状态的 s 只在“文本编辑”类缓冲区里改为 Avy；原替换字符操作可用 cl，其他状态不改。
  ;; 文本编辑 = text-mode、prog-mode、conf-mode 及其派生（Org、Markdown、Lisp、C、.gitignore 等），
  ;; 以及没有专门模式的纯文本文件（fundamental-mode）。
  ;; 其他模式（Dired、ibuffer、Magit、帮助页等）条件不成立，条件分派返回 nil，
  ;; 这一层不给出命令，按键继续往下找，各模式自己的 s 照常生效（Magit 暂存、ibuffer 筛选前缀……）。
  ;; general-predicate-dispatch 的第一个参数是默认值（nil：不绑定），后面是“条件 命令”成对出现。
  ;; Avy 仍可在任何界面用 , j j 调用。
  (general-define-key
   :states 'normal
   :keymaps 'override
   "s" (general-predicate-dispatch nil
         (or (derived-mode-p 'text-mode 'prog-mode 'conf-mode)
             (eq major-mode 'fundamental-mode))
         #'avy-goto-char-timer))  ; Jump，字符标签跳转；仅文本编辑模式

  ;; 此前未自定义全局 Esc；这里只绑定独立事件，不覆盖 ESC / Meta 前缀。
  ;; Evil 的插入／可视状态仍优先使用原来的 Esc，C-g 继续保留取消／中断用途。
  (general-def "<escape>" #'keyboard-escape-quit)  ; Escape，按上下文退出当前交互

  ;; F10 原为菜单入口，F11 原为全屏；替代调用方式见诊断与配置状态章节。
  ;; F11 会把求值结果写入正文；F12 只在底部显示结果，不插入正文。
  (general-def
    "<f9>"  #'liyunfeng/set-variable                    ; Set variable，临时设置变量
    "<f10>" #'liyunfeng/find-config-source              ; Find config，选择配置源文件
    "<f11>" #'liyunfeng/eval-last-sexp-insert-result     ; Evaluate and insert，求值并插入结果
    "<f12>" #'liyunfeng/eval-last-sexp)                 ; Evaluate，求值并显示结果

  ;; 全局备用前缀访问同一份菜单，适用于插入状态及 Emacs 状态。
  ;; 原生 C-h 前缀保留，只增强其中几个具体帮助命令。
  (general-def
    "C-c ," my/leader-map        ; Leader，备用功能前缀
    "C-." #'embark-act           ; Act，上下文与候选动作菜单
    "C-h k" #'helpful-key        ; Key，按键帮助
    "C-h f" #'helpful-callable   ; Function，函数帮助
    "C-h v" #'helpful-variable   ; Variable，变量帮助
    "C-h x" #'helpful-command))  ; Execute，交互命令帮助

(with-eval-after-load 'dashboard
  ;; 这五个键也是插件默认值；只在 Dashboard 中定位栏目，不直接打开列表条目。
  ;; 页面内原有 Evil 字母动作让位于栏目导航，文本缓冲区不受影响。
  (setq dashboard-item-shortcuts
        '((recents . "r")              ; Recents，最近文件
          (bookmarks . "m")            ; Marks，书签
          (projects . "p")             ; Projects，项目
          (agenda . "a")               ; Agenda，日程
          (registers . "e"))))          ; Registers，寄存器

;;; Dired 的 Vim 式目录导航；等 Dired 加载后绑定，保证晚于 evil-collection 的适配。
(with-eval-after-load 'dired
  (general-define-key
   :states 'normal
   :keymaps 'dired-mode-map
   "h" #'dired-up-directory   ; Up，返回上级目录
   "l" #'dired-find-file))    ; Open，打开文件或进入目录

;;; 可选 Evil 初始状态：以下全为注释，normal/emacs 是示例选择，不是插件默认值。
;; 文本与配置编辑：普通状态示例，按 i 开始输入。
;; (evil-set-initial-state 'fundamental-mode 'normal)
;; (evil-set-initial-state 'text-mode 'normal)
;; (evil-set-initial-state 'org-mode 'normal)
;; (evil-set-initial-state 'emacs-lisp-mode 'normal)
;; (evil-set-initial-state 'lisp-interaction-mode 'normal)
;; (evil-set-initial-state 'prog-mode 'normal)

;; 文件、列表与帮助页面：普通状态示例，保留各模式的只读约束。
;; (evil-set-initial-state 'dired-mode 'normal)
;; (evil-set-initial-state 'ibuffer-mode 'normal)
;; (evil-set-initial-state 'Buffer-menu-mode 'normal)
;; (evil-set-initial-state 'bookmark-bmenu-mode 'normal)
;; (evil-set-initial-state 'recentf-dialog-mode 'normal)
;; (evil-set-initial-state 'help-mode 'normal)
;; (evil-set-initial-state 'helpful-mode 'normal)
;; (evil-set-initial-state 'Info-mode 'normal)
;; (evil-set-initial-state 'apropos-mode 'normal)
;; (evil-set-initial-state 'messages-buffer-mode 'normal)
;; (evil-set-initial-state 'Custom-mode 'normal)
;; (evil-set-initial-state 'custom-theme-choose-mode 'normal)
;; (evil-set-initial-state 'debugger-mode 'normal)

;; 搜索、诊断与候选收集；minibuffer／Vertico 不是另一个主模式，不在这里统一设状态。
;; (evil-set-initial-state 'occur-mode 'normal)
;; (evil-set-initial-state 'grep-mode 'normal)
;; (evil-set-initial-state 'compilation-mode 'normal)
;; (evil-set-initial-state 'embark-collect-mode 'normal)

;; Magit 主要页面：模式有派生关系，子模式的特定设置可能覆盖父模式。
;; (evil-set-initial-state 'magit-mode 'normal)
;; (evil-set-initial-state 'magit-status-mode 'normal)
;; (evil-set-initial-state 'magit-diff-mode 'normal)
;; (evil-set-initial-state 'magit-log-mode 'normal)
;; (evil-set-initial-state 'magit-log-select-mode 'normal)
;; (evil-set-initial-state 'magit-revision-mode 'normal)
;; (evil-set-initial-state 'magit-merge-preview-mode 'normal)
;; (evil-set-initial-state 'magit-reflog-mode 'normal)
;; (evil-set-initial-state 'magit-refs-mode 'normal)
;; (evil-set-initial-state 'magit-stash-mode 'normal)
;; (evil-set-initial-state 'magit-stashes-mode 'normal)
;; (evil-set-initial-state 'magit-cherry-mode 'normal)
;; (evil-set-initial-state 'magit-process-mode 'normal)
;; (evil-set-initial-state 'magit-repolist-mode 'normal)
;; (evil-set-initial-state 'magit-submodule-list-mode 'normal)

;; 提交消息通常是 text-mode；git-commit-mode 是辅助模式，不能当作这里的主模式。
;; (evil-set-initial-state 'git-rebase-mode 'normal)

;; 终端与交互输入：emacs 状态示例，让原生键位接手；term 还区分字符／行模式。
;; (evil-set-initial-state 'shell-mode 'emacs)
;; (evil-set-initial-state 'eshell-mode 'emacs)
;; (evil-set-initial-state 'term-mode 'emacs)
;; (evil-set-initial-state 'comint-mode 'emacs)
;; (evil-set-initial-state 'ielm-mode 'emacs)

;; 可选功能：尚未配置或未启用的模式，写入示例不安装任何插件。
;; (evil-set-initial-state 'dashboard-mode 'normal)
;; (evil-set-initial-state 'message-mode 'normal)
;; (evil-set-initial-state 'calendar-mode 'normal)
;; (evil-set-initial-state 'doc-view-mode 'normal)
;; (evil-set-initial-state 'image-mode 'normal)
;; (evil-set-initial-state 'diff-mode 'normal)

;;; init.el ends here
