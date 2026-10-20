;;; init.el --- Generated Emacs configuration -*- lexical-binding: t; -*-
;; Generated from org_configs/Windows_config.org. Edit the Org source instead.
;; 本文件由 Org 生成；注释也维护在 Org 代码块中，避免下次生成时丢失。
;; 已配置基础环境、Org 目录、Vim 编辑、帮助和 leader；搜索与开发等仍占位。

;;; 基础入口

;; 以 init.el 所在目录为配置根目录，避免依赖启动时的工作目录。
(defconst my/config-directory
  (file-name-directory (or load-file-name user-init-file))
  "Directory containing this configuration's generated init.el.")

;; 关闭欢迎页，在 scratch 中显示加载提示。
(setq inhibit-startup-screen t
      initial-scratch-message ";; Org config loaded successfully.\n\n")

;;; Custom 状态独立保存，避免污染由 Org 生成的 init.el。
;; 尽早设置：首次安装插件时，包选择记录也应写到 custom.el。
(setq custom-file (expand-file-name "custom.el" my/config-directory))
(load custom-file 'noerror 'nomessage)

;;; 网络代理
;; 仅影响 Emacs URL 库，不会替 Git、clangd 等外部程序设置代理。
(require 'url-vars)

;; 不需要显式代理时改为 nil；已有的进程代理环境变量不受此设置清除。
(defvar my/proxy-address "127.0.0.1:10808"
  "Local HTTP proxy address, or nil to omit explicit URL proxies.")

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

;;; 本机特例：MSYS2 GPG 路径兼容
;; 仅修复当前已复现问题的可执行文件路径，不是所有 Windows 都需要此设置。
;; 其他 Windows、Linux、macOS 保留默认 GPG 选择；不关闭签名校验。
(require 'epg-config)

(when (eq system-type 'windows-nt)
  (let ((detected (executable-find epg-gpg-program))
        (affected "D:/Software/Msys2/usr/bin/gpg.exe")
        (replacement "D:/Software/Git/usr/bin/gpg.exe"))
    (when (and detected
               (string-equal (downcase detected) (downcase affected))
               (file-executable-p replacement))
      ;; EasyPG 会检查自定义状态；仅 setq 可能仍让它重新从 PATH 选择程序。
      (customize-set-variable 'epg-gpg-program replacement)
      ;; 清除指向旧 GPG 的配置缓存，让后续校验使用替代程序。
      (setq epg--configurations nil))))

;;; 通用签名密钥环与软件源初始化
;; 各平台共用独立的 ELPA 密钥环，不修改个人日常使用的 GPG 密钥环。
(setq package-gnupghome-dir (expand-file-name "gnupg/" package-user-dir))

(require 'epg)

(unless (epg-find-configuration 'OpenPGP)
  (error "GnuPG not found or unusable; install GnuPG and check Emacs exec-path"))

(let ((context (epg-make-context 'OpenPGP)))
  (setf (epg-context-home-directory context) package-gnupghome-dir)
  ;; 初次使用或之前初始化失败留下空密钥环时，导入 Emacs 自带的 ELPA 公钥。
  (unless (epg-list-keys context)
    (package-import-keyring (expand-file-name "package-keyring.gpg" data-directory))))

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

;;; Org 自动目录
;; Org 缓冲区启用 toc-org，但只为带 TOC 标签的文档在保存时更新目录。
;; 本配置文档使用 :TOC_4_org:；目前目录只有标题链接，不包含章节编号。
;; 不配置全局 org-num hook；正文编号由每份文件的 #+startup: num 决定。
(use-package toc-org
  :hook (org-mode . toc-org-mode))

;;; Vim 编辑：Evil
;; 必须先关闭 Evil 自带的部分模式键位，交由 evil-collection 统一适配。
;; 这是加载前选项，必须放在 :init；自定义按键集中在文件末尾。
(use-package evil
  :demand t
  :init
  (setq evil-want-keybinding nil)
  :config
  ;; Evil 1.15.0 仍读取旧的初始化队列；Emacs 31.1 不再创建该变量。
  ;; 只在已知版本组合且变量未定义时补空队列，不覆盖其他版本或已有状态。
  (when (and (version= emacs-version "31.1")
             (string= evil-version "1.15.0")
             (not (boundp 'evil-mode-buffers)))
    (set-default 'evil-mode-buffers nil))
  (evil-mode 1))

;;; 工具界面的 Vim 键位
;; 为 Dired、帮助等受支持模式适配键位；模式打开时按需应用。
(use-package evil-collection
  :after evil
  :demand t
  :config
  (evil-collection-init))

;;; Surround：ys + motion/text-object + 新包围符；ds + 旧包围符；cs + 旧 + 新。
;; iw/aw 是普通文本对象；ysiw" 包整个词，yse" 包到词尾。详见 Org 中的语法说明。
(use-package evil-surround
  :after evil
  :demand t
  :config
  (global-evil-surround-mode 1))

;;; 帮助增强：调用时加载 Helpful，安装由 use-package 处理。
;; 实际按键在末尾统一绑定，不在这里覆盖任何模式键位。
(use-package helpful
  :commands (helpful-key helpful-callable helpful-command
             helpful-variable helpful-at-point))

;;; 前缀按键提示：输入 leader 后稍等，显示下一步可用命令。
(use-package which-key
  :ensure nil
  :demand t
  :custom
  (which-key-idle-delay 0.5)
  :config
  (which-key-mode 1))

;;; Window configuration history：内置 Winner 记录布局历史；最大化切换另存 Frame 布局。
(use-package winner
  :ensure nil
  :demand t
  :config
  (winner-mode 1))

;;; 窗口布局与文件辅助命令；Org 生成和目录更新直接使用原生命令。
;; Window maximize：布局保存在当前 Frame 参数中，各 Frame 互不干扰。
(defun my/toggle-window-maximize ()
  "Toggle between the current window layout and a single window."
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
  "Copy the current file's absolute path to the kill ring."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (let ((path (expand-file-name buffer-file-name)))
    (kill-new path)
    (message "Copied: %s" path)))

;;; 统一键位：General 管理绑定，which-key 显示随 keymap 保存的中文描述。
(use-package general
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

  (general-def my/file-map
    "f" '("打开文件" . find-file)                   ; Find file，打开文件
    "s" '("保存文件" . save-buffer)                 ; Save，保存
    "a" '("另存为" . write-file)                    ; Save as，另存为
    "d" '("目录管理" . dired)                       ; Dired，目录管理
    ;; 保留内置确认：不要用无提示覆盖方式重新读取有未保存修改的文件。
    "u" '("重新读取文件" . revert-buffer)           ; Update from disk，重新读取磁盘内容
    "p" '("复制文件完整路径" . my/copy-file-path))  ; Path，文件完整路径

  (general-def my/buffer-map
    "b" '("切换缓冲区" . switch-to-buffer)         ; Buffer，选择缓冲区
    "i" '("缓冲区列表" . ibuffer)                  ; Ibuffer，缓冲区管理列表
    "k" '("关闭当前缓冲区" . kill-current-buffer)  ; Kill，关闭缓冲区
    "n" '("下一个缓冲区" . next-buffer)            ; Next，下一个
    "p" '("上一个缓冲区" . previous-buffer))       ; Previous，上一个

  (general-def my/help-map
    "k" '("解释按键" . helpful-key)                          ; Key，按键帮助
    "f" '("函数帮助" . helpful-callable)                     ; Function，函数帮助
    "x" '("命令帮助" . helpful-command)                      ; Execute，交互命令帮助
    "v" '("变量帮助" . helpful-variable)                     ; Variable，变量帮助
    "." '("光标处 Lisp 符号" . helpful-at-point)             ; At point，光标处符号
    "m" '("当前模式说明" . describe-mode)                    ; Mode，当前模式
    "b" '("当前有效键位" . describe-bindings)                ; Bindings，有效键位
    "w" '("查找命令按键" . where-is)                         ; Where is，查找命令绑定
    "a" '("按名称找命令" . apropos-command)                  ; Apropos，按名称查找
    "i" '("Emacs 手册" . info-emacs-manual)                  ; Info，Emacs 手册
    "g" '("自定义键位清单" . general-describe-keybindings))  ; General，自定义键位

  ;; Diagnostics：诊断；Messages 和 Debug 各保留一个入口。
  (general-def my/diagnostic-map
    "m" '("查看消息" . view-echo-area-messages)  ; Messages，消息日志
    "d" '("错误回溯" . toggle-debug-on-error))   ; Debug，错误回溯开关

  ;; Window，窗口布局；关闭显示区域不关闭其中的 Buffer。
  (general-def my/window-map
    "h" '("左侧窗口" . windmove-left)                   ; Left，沿用 Vim 向左键
    "j" '("下方窗口" . windmove-down)                   ; Down，沿用 Vim 向下键
    "k" '("上方窗口" . windmove-up)                     ; Up，沿用 Vim 向上键
    "l" '("右侧窗口" . windmove-right)                  ; Right，沿用 Vim 向右键
    "c" '("关闭当前窗口" . delete-window)               ; Close，关闭窗口
    "w" '("下一个窗口" . other-window)                  ; Window，循环切换窗口
    "s" '("上下拆分" . split-window-below)              ; Split，上下拆分
    "v" '("左右拆分" . split-window-right)              ; Vertical split，左右拆分
    "o" '("保留当前窗口" . delete-other-windows)        ; Only，只保留当前窗口
    "m" '("最大化或恢复" . my/toggle-window-maximize))  ; Maximize，最大化或恢复

  ;; Quit：退出；Q 按用户选择提供强制退出，跳过常规保存询问。
  (general-def my/quit-map
    "q" '("退出当前窗口或会话" . evil-quit)             ; Quit，当前窗口或会话
    "a" '("退出终端会话" . save-buffers-kill-terminal)  ; All，检查保存后退出会话
    "Q" '("强制退出进程" . kill-emacs))                 ; Force quit，跳过常规保存询问

  ;; Org，文档与配置维护，保留标题与结构导航入口。
  ;; 标题跳转与代码块编辑在 Org 中调用；生成和目录更新使用原生命令。
  (general-def my/org-map
    "b" '("生成当前文档代码" . org-babel-tangle)    ; Babel，提取当前 Org 代码，不执行或加载
    "g" '("Org 标题跳转" . org-goto)                ; Go to，跳转标题
    "i" '("当前文件结构索引" . imenu)               ; Index，结构索引
    "t" '("更新当前文档目录" . toc-org-insert-toc)  ; Table of contents，当前文档目录
    "s" '("编辑 Org 代码块" . org-edit-special))  ; Special，专用编辑界面

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
    "o" (cons "文档与配置" my/org-map))  ; Org，文档与配置

  ;; 普通／可视／motion 状态使用逗号；插入状态不占用逗号。
  ;; motion 覆盖一些只读工具界面；override 减少局部模式遮挡 leader。
  (general-define-key
   :states '(normal visual motion)
   :keymaps 'override
   "," my/leader-map)

  ;; 全局备用前缀访问同一份菜单，适用于插入状态及 Emacs 状态。
  ;; 原生 C-h 前缀保留，只增强其中几个具体帮助命令。
  (general-def
    "C-c ," my/leader-map        ; Leader，备用功能前缀
    "C-h k" #'helpful-key        ; Key，按键帮助
    "C-h f" #'helpful-callable   ; Function，函数帮助
    "C-h v" #'helpful-variable   ; Variable，变量帮助
    "C-h x" #'helpful-command))  ; Execute，交互命令帮助

;;; init.el ends here
