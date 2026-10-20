;;; init.el --- Generated Emacs configuration -*- lexical-binding: t; -*-
;; Generated from org_configs/Windows_config.org. Edit the Org source instead.
;; 本文件由 Org 生成；注释也维护在 Org 代码块中，避免下次生成时丢失。
;; 当前仅启用基础环境和 Org 导航；Evil、搜索、开发等功能仍在源文档中占位。

;;; 基础入口

;; 以 init.el 所在目录为配置根目录，避免依赖启动时的工作目录。
(defconst my/config-directory
  (file-name-directory (or load-file-name user-init-file))
  "Directory containing this configuration's generated init.el.")

;; 关闭欢迎页，在 scratch 中显示加载提示。
(setq inhibit-startup-screen t
      initial-scratch-message ";; Org config loaded successfully.\n\n")

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

;;; init.el ends here
