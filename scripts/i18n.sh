# i18n.sh — shared translations + fmt() for the Proton Pass shell entry points.
# Sourced, not executed: `source "$SCRIPT_DIR/i18n.sh"` after SCRIPT_DIR is set.
# Defines one namespace (lang, generic, fmt(), and all msg_*/a_*/lbl_* prompts)
# used by copy-value, copy-secret, pass-pick and pass-autotype — no script keeps
# its own i18n block anymore.

raw_lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
lang="$(echo "${raw_lang%%.*}" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]')"
case "$lang" in fr|zh) ;; *) lang="en" ;; esac
generic="${PASS_GENERIC_NOTIFY:-0}"

fmt() { # fmt <template> <arg1> [arg2] [arg3]
  local out="$1"; shift
  local i=1
  while (( $# > 0 )); do
    out="${out//%$i/$1}"
    shift; ((i++))
  done
  printf '%s' "$out"
}

if [[ "$lang" == "fr" ]]; then
  # copy-value (short clipboard notifications)
  msg_copied="Copié"
  kind_secret="secret"
  kind_value="valeur"
  msg_of_item='%1 « %2 » (%3 s)'
  msg_generic='%1 copié (%2 s)'

  # pass-autotype
  msg_wtype_missing_title="wtype manquant"
  msg_read_failed_autotype_body='Échec de lecture du mot de passe pour « %1 ».'
  msg_autotype_soon_body="Automatisation dans 3 s — changez de fenêtre pour annuler."
  msg_autotype_done_body_generic="Autatype terminé"
  msg_autotype_done_body='Autatype terminé : %1'

  # copy-secret
  msg_missing_cli_title="pass-cli introuvable"
  msg_install_hint="Installez proton-pass-cli."
  msg_missing_wlcopy_title="wl-copy manquant"
  msg_wlcopy_needed="wl-clipboard est requis pour copier."
  msg_read_failed="Échec de lecture"
  msg_read_body='%1 pour « %2 »'
  msg_read_body_generic='%1'
  msg_no_totp="Pas de code TOTP"
  msg_no_totp_body="Aucun code TOTP configuré pour « %1 »."
  msg_no_totp_body_generic="Aucun code TOTP configuré pour cet élément."
  msg_copied_generic="Secret copié"
  lbl_totp="code TOTP"
  lbl_password="mot de passe"
  lbl_username="identifiant"

  # pass-pick (menu + item prompts)
  prompt_items="Proton Pass — rechercher"
  prompt_field="Quelle action ?"
  a_username="Copier l'identifiant"
  a_password="Copier le mot de passe"
  a_totp="Copier le code TOTP"
  a_url="Copier l'URL"
  a_open="Ouvrir l'URL"
  a_autotype="Autatype (identifiant ⇥ mot de passe)"
  a_detail="Ouvrir le détail dans le panneau"
  lbl_login="Connexion"; lbl_alias="Alias"; lbl_note="Note sécurisée"
  lbl_card="Carte bancaire"; lbl_identity="Identité"; lbl_ssh="Clé SSH"
  lbl_wifi="Wi-Fi"; lbl_other="Autre"
  msg_cache_fail="Cache Proton Pass indisponible"
  msg_cache_fail_body="Lancement du rafraîchissement… réessaie dans un instant."
  msg_stale="Cache Proton Pass périmé"
  msg_stale_body="Rafraîchissement en arrière-plan."
  msg_shell_down="Omarchy shell injoignable"
  msg_shell_down_body="Le sélecteur a besoin du shell (omarchy-shell)."
  msg_item_fail="Échec de lecture de l'élément"

elif [[ "$lang" == "zh" ]]; then
  # copy-value
  msg_copied="已复制"
  kind_secret="机密"
  kind_value="值"
  msg_of_item='%2 的 %1（%3 秒）'
  msg_generic='%1 已复制（%2 秒）'

  # copy-secret
  msg_missing_cli_title="未找到 pass-cli"
  msg_install_hint="请安装 proton-pass-cli。"
  msg_missing_wlcopy_title="缺少 wl-copy"
  msg_wlcopy_needed="需要 wl-clipboard 才能复制。"
  msg_read_failed="读取失败"
  msg_read_body='“%2”的 %1'
  msg_read_body_generic='%1'
  msg_no_totp="没有 TOTP 验证码"
  msg_no_totp_body="“%1”未配置 TOTP 验证码。"
  msg_no_totp_body_generic="该项目未配置 TOTP 验证码。"
  msg_copied_generic="已复制机密"
  lbl_totp="TOTP 验证码"
  lbl_password="密码"
  lbl_username="用户名"

  # pass-pick
  prompt_items="Proton Pass — 搜索"
  prompt_field="选择操作"
  a_username="复制用户名"
  a_password="复制密码"
  a_totp="复制 TOTP 验证码"
  a_url="复制 URL"
  a_open="打开 URL"
  a_autotype="自动输入（用户名 ⇥ 密码）"
  a_detail="在面板中打开详情"
  lbl_login="登录"; lbl_alias="别名"; lbl_note="安全笔记"
  lbl_card="银行卡"; lbl_identity="身份信息"; lbl_ssh="SSH 密钥"
  lbl_wifi="Wi-Fi"; lbl_other="其他"
  msg_cache_fail="Proton Pass 缓存不可用"
  msg_cache_fail_body="正在刷新…请稍后重试。"
  msg_stale="Proton Pass 缓存已过期"
  msg_stale_body="正在后台刷新。"
  msg_shell_down="Omarchy shell 不可用"
  msg_shell_down_body="选择器需要 shell（omarchy-shell）。"
  msg_item_fail="读取项目失败"

else # English (default)
  # copy-value
  msg_copied="Copied"
  kind_secret="secret"
  kind_value="value"
  msg_of_item='%1 "%2" (%3 s)'
  msg_generic='%1 copied (%2 s)'

  # pass-autotype
  msg_wtype_missing_title="wtype missing"
  msg_read_failed_autotype_body='Failed to read the password for "%1".'
  msg_autotype_soon_body="Autotyping in 3 seconds — switch away to cancel."
  msg_autotype_done_body_generic="Autotyping done"
  msg_autotype_done_body="Autotyping done: %1"

  # copy-secret
  msg_missing_cli_title="pass-cli not found"
  msg_install_hint="Install proton-pass-cli."
  msg_missing_wlcopy_title="wl-copy missing"
  msg_wlcopy_needed="wl-clipboard is required to copy."
  msg_read_failed="Failed to read"
  msg_read_body='%1 for "%2"'
  msg_read_body_generic='%1'
  msg_no_totp="No TOTP code"
  msg_no_totp_body="No TOTP configured for \"%1\"."
  msg_no_totp_body_generic="No TOTP configured for this item."
  msg_copied_generic="Secret copied"
  lbl_totp="TOTP code"
  lbl_password="password"
  lbl_username="username"

  # pass-pick
  prompt_items="Proton Pass — search"
  prompt_field="Which action?"
  a_username="Copy username"
  a_password="Copy password"
  a_totp="Copy TOTP code"
  a_url="Copy URL"
  a_open="Open URL"
  a_autotype="Autotyping (username ⇥ password)"
  a_detail="Open details in the panel"
  lbl_login="Login"; lbl_alias="Alias"; lbl_note="Secure note"
  lbl_card="Credit card"; lbl_identity="Identity"; lbl_ssh="SSH key"
  lbl_wifi="Wi-Fi"; lbl_other="Other"
  msg_cache_fail="Proton Pass cache unavailable"
  msg_cache_fail_body="Refreshing now… try again in a moment."
  msg_stale="Proton Pass cache is stale"
  msg_stale_body="Refreshing in the background."
  msg_shell_down="Omarchy shell unreachable"
  msg_shell_down_body="The picker needs the shell (omarchy-shell)."
  msg_item_fail="Failed to read the item"
fi
