// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum FaceUnlockText: Int, CaseIterable {
    case title, summary, notice, accept, authorize, sessionHint, password, save, enroll, recapture, faceHint, front, left, right, up, down, enable, pause, forget, forgetConfirm, cancel, capture, ready, off, setup, saved, scanning, submitted, timeout, failed, cameraDenied, noCamera, camera, automatic, indicator, privacy, permissions, delete, learnMore, cameraUse
}

/// All app languages have complete, explicit entries; coverage is tested.
struct FaceUnlockStrings {
    let language: AppLanguage
    init(_ language: AppLanguage) { self.language = language }
    static var current: Self { Self(L10n.shared.language) }
    subscript(_ key: FaceUnlockText) -> String { Self.translations[language]![key.rawValue] }
    static let translations: [AppLanguage: [String]] = [
        .enUS: [
            "Face Unlock", // title
            "Unlock your Mac with Glance, using your camera.", // summary
            "A webcam is not Face ID. Photos or videos may fool it. Glance types your saved Mac password at the lock screen; it cannot unlock FileVault after a restart. Use only if you accept this tradeoff.", // notice
            "I understand and accept", // accept
            "Authorize this session", // authorize
            "Authenticate after each app launch. Pause or quit to clear the session key.", // sessionHint
            "Mac login password", // password
            "Verify and save", // save
            "Enroll your face", // enroll
            "Replace enrollment", // recapture
            "Keep only your face in the frame, in good light. Capture five clear views.", // faceHint
            "Look straight ahead", // front
            "Turn slightly left", // left
            "Turn slightly right", // right
            "Tilt slightly up", // up
            "Tilt slightly down", // down
            "Enable face unlock", // enable
            "Pause session", // pause
            "Forget face and password", // forget
            "Delete this app’s enrolled face and saved password? You can set up again later.", // forgetConfirm
            "Cancel", // cancel
            "Capture view", // capture
            "Ready for the next lock or wake", // ready
            "Face unlock is off", // off
            "Complete setup below", // setup
            "Saved", // saved
            "Look at the camera and blink", // scanning
            "Password submitted", // submitted
            "No match. Use your Mac password or wake the display to retry.", // timeout
            "Could not complete the operation", // failed
            "Allow Camera in System Settings → Privacy & Security.", // cameraDenied
            "The selected camera is unavailable. Choose a connected camera.", // noCamera
            "Camera", // camera
            "Built-in or default camera", // automatic
            "Show lock-screen indicator", // indicator
            "Face templates and your password are encrypted locally. Camera frames are not saved or sent anywhere.", // privacy
            "Permissions", // permissions
            "Delete", // delete
            "About Glance", // learnMore
            "Uses the camera for a preview or, when Face Unlock is set up, to enroll and recognize your face. Nothing is recorded or sent off your Mac.", // cameraUse
        ],
        .ptBR: [
            "Desbloqueio facial", // title
            "Desbloqueie seu Mac com o Glance pela câmera.", // summary
            "Uma webcam não é o Face ID. Fotos ou vídeos podem enganá-la. O Glance digita a senha salva do Mac na tela bloqueada; não desbloqueia o FileVault após reiniciar. Use apenas se aceitar essa limitação.", // notice
            "Entendo e aceito", // accept
            "Autorizar esta sessão", // authorize
            "Autentique-se após abrir o app. Pause ou saia para limpar a chave da sessão.", // sessionHint
            "Senha de início de sessão do Mac", // password
            "Verificar e salvar", // save
            "Cadastrar seu rosto", // enroll
            "Substituir cadastro", // recapture
            "Mantenha apenas seu rosto no quadro, com boa iluminação. Capture cinco vistas nítidas.", // faceHint
            "Olhe para a frente", // front
            "Vire um pouco à esquerda", // left
            "Vire um pouco à direita", // right
            "Incline um pouco para cima", // up
            "Incline um pouco para baixo", // down
            "Ativar desbloqueio facial", // enable
            "Pausar sessão", // pause
            "Esquecer rosto e senha", // forget
            "Excluir o rosto cadastrado e a senha salva neste app? Você pode configurar novamente depois.", // forgetConfirm
            "Cancelar", // cancel
            "Capturar vista", // capture
            "Pronto para o próximo bloqueio ou despertar", // ready
            "O desbloqueio facial está desativado", // off
            "Conclua a configuração abaixo", // setup
            "Salvo", // saved
            "Olhe para a câmera e pisque", // scanning
            "Senha enviada", // submitted
            "Nenhuma correspondência. Use a senha do Mac ou desperte a tela para tentar novamente.", // timeout
            "Não foi possível concluir a operação", // failed
            "Permita Câmera em Ajustes do Sistema → Privacidade e Segurança.", // cameraDenied
            "A câmera selecionada está indisponível. Escolha uma câmera conectada.", // noCamera
            "Câmera", // camera
            "Câmera integrada ou padrão", // automatic
            "Mostrar indicador na tela bloqueada", // indicator
            "Os dados faciais e a senha são criptografados localmente. As imagens da câmera não são salvas nem enviadas.", // privacy
            "Permissões", // permissions
            "Excluir", // delete
            "Sobre o Glance", // learnMore
            "Usa a câmera para prévia ou, com o desbloqueio facial configurado, para cadastrar e reconhecer seu rosto. Nada é gravado nem sai do Mac.", // cameraUse
        ],
        .es: [
            "Desbloqueo facial", // title
            "Desbloquea tu Mac con Glance y tu cámara.", // summary
            "Una webcam no es Face ID. Las fotos o los vídeos pueden engañarla. Glance escribe tu contraseña guardada en la pantalla de bloqueo; no desbloquea FileVault tras reiniciar. Úsalo solo si aceptas esta limitación.", // notice
            "Lo entiendo y acepto", // accept
            "Autorizar esta sesión", // authorize
            "Autentícate al abrir la app. Pausa o sal para borrar la clave de sesión.", // sessionHint
            "Contraseña de inicio de sesión del Mac", // password
            "Verificar y guardar", // save
            "Registrar tu rostro", // enroll
            "Reemplazar registro", // recapture
            "Mantén solo tu rostro en el encuadre, con buena luz. Captura cinco vistas claras.", // faceHint
            "Mira al frente", // front
            "Gira un poco a la izquierda", // left
            "Gira un poco a la derecha", // right
            "Inclina un poco hacia arriba", // up
            "Inclina un poco hacia abajo", // down
            "Activar desbloqueo facial", // enable
            "Pausar sesión", // pause
            "Olvidar rostro y contraseña", // forget
            "¿Eliminar el rostro registrado y la contraseña guardada en esta app? Puedes configurarlos de nuevo.", // forgetConfirm
            "Cancelar", // cancel
            "Capturar vista", // capture
            "Listo para el próximo bloqueo o activación", // ready
            "El desbloqueo facial está desactivado", // off
            "Completa la configuración de abajo", // setup
            "Guardado", // saved
            "Mira a la cámara y parpadea", // scanning
            "Contraseña enviada", // submitted
            "Sin coincidencia. Usa la contraseña del Mac o activa la pantalla para reintentar.", // timeout
            "No se pudo completar la operación", // failed
            "Permite Cámara en Ajustes del Sistema → Privacidad y seguridad.", // cameraDenied
            "La cámara seleccionada no está disponible. Elige una cámara conectada.", // noCamera
            "Cámara", // camera
            "Cámara integrada o predeterminada", // automatic
            "Mostrar indicador en la pantalla de bloqueo", // indicator
            "Los datos faciales y la contraseña se cifran localmente. Las imágenes no se guardan ni se envían.", // privacy
            "Permisos", // permissions
            "Eliminar", // delete
            "Acerca de Glance", // learnMore
            "Usa la cámara como espejo o, al configurar el desbloqueo facial, para registrar y reconocer tu rostro. No se graba ni se envía nada fuera del Mac.", // cameraUse
        ],
        .fr: [
            "Déverrouillage facial", // title
            "Déverrouillez votre Mac avec Glance et votre caméra.", // summary
            "Une webcam n’est pas Face ID. Des photos ou vidéos peuvent la tromper. Glance saisit votre mot de passe enregistré sur l’écran verrouillé ; il ne déverrouille pas FileVault après un redémarrage. N’utilisez cette fonction que si vous acceptez ce compromis.", // notice
            "Je comprends et j’accepte", // accept
            "Autoriser cette session", // authorize
            "Authentifiez-vous à chaque ouverture de l’app. Mettez en pause ou quittez pour effacer la clé de session.", // sessionHint
            "Mot de passe de session du Mac", // password
            "Vérifier et enregistrer", // save
            "Enregistrer votre visage", // enroll
            "Remplacer le visage", // recapture
            "Gardez uniquement votre visage dans le cadre, bien éclairé. Capturez cinq vues nettes.", // faceHint
            "Regardez devant vous", // front
            "Tournez légèrement à gauche", // left
            "Tournez légèrement à droite", // right
            "Inclinez légèrement vers le haut", // up
            "Inclinez légèrement vers le bas", // down
            "Activer le déverrouillage facial", // enable
            "Suspendre la session", // pause
            "Oublier le visage et le mot de passe", // forget
            "Supprimer le visage et le mot de passe enregistrés dans cette app ? Vous pourrez les configurer à nouveau.", // forgetConfirm
            "Annuler", // cancel
            "Capturer la vue", // capture
            "Prêt au prochain verrouillage ou réveil", // ready
            "Le déverrouillage facial est désactivé", // off
            "Terminez la configuration ci-dessous", // setup
            "Enregistré", // saved
            "Regardez la caméra et clignez des yeux", // scanning
            "Mot de passe envoyé", // submitted
            "Aucune correspondance. Utilisez le mot de passe du Mac ou réveillez l’écran pour réessayer.", // timeout
            "Impossible de terminer l’opération", // failed
            "Autorisez Caméra dans Réglages Système → Confidentialité et sécurité.", // cameraDenied
            "La caméra choisie est indisponible. Choisissez une caméra connectée.", // noCamera
            "Caméra", // camera
            "Caméra intégrée ou par défaut", // automatic
            "Afficher l’indicateur sur l’écran verrouillé", // indicator
            "Le visage et le mot de passe sont chiffrés localement. Les images ne sont ni enregistrées ni envoyées.", // privacy
            "Autorisations", // permissions
            "Supprimer", // delete
            "À propos de Glance", // learnMore
            "Utilise la caméra comme miroir ou, après configuration, pour enregistrer et reconnaître votre visage. Rien n’est enregistré ni envoyé hors du Mac.", // cameraUse
        ],
        .de: [
            "Gesichtsentsperrung", // title
            "Entsperre deinen Mac mit Glance über die Kamera.", // summary
            "Eine Webcam ist kein Face ID. Fotos oder Videos können sie täuschen. Glance gibt dein gespeichertes Mac-Passwort am Sperrbildschirm ein; FileVault wird nach einem Neustart nicht entsperrt. Nutze dies nur, wenn du diesen Nachteil akzeptierst.", // notice
            "Ich verstehe und akzeptiere", // accept
            "Diese Sitzung autorisieren", // authorize
            "Authentifiziere dich nach jedem App-Start. Pausiere oder beende die App, um den Sitzungsschlüssel zu löschen.", // sessionHint
            "Mac-Anmeldepasswort", // password
            "Prüfen und speichern", // save
            "Gesicht erfassen", // enroll
            "Erfassung ersetzen", // recapture
            "Halte nur dein Gesicht bei gutem Licht im Bild. Nimm fünf klare Ansichten auf.", // faceHint
            "Geradeaus schauen", // front
            "Leicht nach links drehen", // left
            "Leicht nach rechts drehen", // right
            "Leicht nach oben neigen", // up
            "Leicht nach unten neigen", // down
            "Gesichtsentsperrung aktivieren", // enable
            "Sitzung pausieren", // pause
            "Gesicht und Passwort vergessen", // forget
            "Gespeichertes Gesicht und Passwort dieser App löschen? Du kannst sie später neu einrichten.", // forgetConfirm
            "Abbrechen", // cancel
            "Ansicht aufnehmen", // capture
            "Bereit beim nächsten Sperren oder Aufwachen", // ready
            "Gesichtsentsperrung ist aus", // off
            "Einrichtung unten abschließen", // setup
            "Gespeichert", // saved
            "In die Kamera schauen und blinzeln", // scanning
            "Passwort übermittelt", // submitted
            "Keine Übereinstimmung. Nutze dein Mac-Passwort oder wecke das Display für einen neuen Versuch.", // timeout
            "Vorgang konnte nicht abgeschlossen werden", // failed
            "Erlaube Kamera unter Systemeinstellungen → Datenschutz & Sicherheit.", // cameraDenied
            "Die gewählte Kamera ist nicht verfügbar. Wähle eine angeschlossene Kamera.", // noCamera
            "Kamera", // camera
            "Integrierte oder Standardkamera", // automatic
            "Anzeige auf dem Sperrbildschirm", // indicator
            "Gesichtsdaten und Passwort werden lokal verschlüsselt. Kamerabilder werden weder gespeichert noch übertragen.", // privacy
            "Berechtigungen", // permissions
            "Löschen", // delete
            "Über Glance", // learnMore
            "Nutzt die Kamera als Vorschau oder nach Einrichtung zur Gesichtserfassung und -erkennung. Es wird nichts aufgezeichnet oder vom Mac übertragen.", // cameraUse
        ],
        .it: [
            "Sblocco facciale", // title
            "Sblocca il Mac con Glance e la fotocamera.", // summary
            "Una webcam non è Face ID. Foto o video possono ingannarla. Glance digita la password salvata nella schermata di blocco; non sblocca FileVault dopo un riavvio. Usalo solo se accetti questo compromesso.", // notice
            "Ho capito e accetto", // accept
            "Autorizza questa sessione", // authorize
            "Autenticati a ogni avvio dell’app. Metti in pausa o esci per cancellare la chiave di sessione.", // sessionHint
            "Password di accesso al Mac", // password
            "Verifica e salva", // save
            "Registra il tuo volto", // enroll
            "Sostituisci registrazione", // recapture
            "Tieni solo il tuo volto nell’inquadratura, con buona luce. Acquisisci cinque viste nitide.", // faceHint
            "Guarda davanti a te", // front
            "Gira leggermente a sinistra", // left
            "Gira leggermente a destra", // right
            "Inclina leggermente in alto", // up
            "Inclina leggermente in basso", // down
            "Attiva sblocco facciale", // enable
            "Sospendi sessione", // pause
            "Dimentica volto e password", // forget
            "Eliminare il volto registrato e la password salvata in questa app? Puoi configurarli di nuovo.", // forgetConfirm
            "Annulla", // cancel
            "Acquisisci vista", // capture
            "Pronto al prossimo blocco o risveglio", // ready
            "Lo sblocco facciale è disattivato", // off
            "Completa la configurazione sotto", // setup
            "Salvato", // saved
            "Guarda la fotocamera e sbatti le palpebre", // scanning
            "Password inviata", // submitted
            "Nessuna corrispondenza. Usa la password del Mac o riattiva lo schermo per riprovare.", // timeout
            "Impossibile completare l’operazione", // failed
            "Consenti Fotocamera in Impostazioni di Sistema → Privacy e sicurezza.", // cameraDenied
            "La fotocamera scelta non è disponibile. Scegline una collegata.", // noCamera
            "Fotocamera", // camera
            "Fotocamera integrata o predefinita", // automatic
            "Mostra indicatore sulla schermata di blocco", // indicator
            "Volto e password sono crittografati localmente. Le immagini non vengono salvate né inviate.", // privacy
            "Autorizzazioni", // permissions
            "Elimina", // delete
            "Informazioni su Glance", // learnMore
            "Usa la fotocamera come specchio o, dopo la configurazione, per registrare e riconoscere il volto. Nulla viene registrato o inviato fuori dal Mac.", // cameraUse
        ],
        .ja: [
            "顔でロック解除", // title
            "GlanceとカメラでMacのロックを解除します。", // summary
            "WebカメラはFace IDではありません。写真や動画で誤認する可能性があります。Glanceはロック画面に保存したMacのパスワードを入力します。再起動後のFileVaultは解除できません。この制約に同意する場合のみ使用してください。", // notice
            "理解し、同意します", // accept
            "このセッションを認証", // authorize
            "アプリ起動ごとに認証してください。一時停止または終了するとセッションキーを消去します。", // sessionHint
            "Macのログインパスワード", // password
            "確認して保存", // save
            "顔を登録", // enroll
            "登録を置き換え", // recapture
            "明るい場所で自分の顔だけを映し、鮮明な画像を5方向から撮影してください。", // faceHint
            "正面を向く", // front
            "少し左を向く", // left
            "少し右を向く", // right
            "少し上を向く", // up
            "少し下を向く", // down
            "顔でのロック解除を有効にする", // enable
            "セッションを一時停止", // pause
            "顔とパスワードを削除", // forget
            "このアプリに登録した顔と保存したパスワードを削除しますか？後から再設定できます。", // forgetConfirm
            "キャンセル", // cancel
            "撮影", // capture
            "次のロックまたはスリープ解除に対応可能", // ready
            "顔でのロック解除はオフです", // off
            "以下の設定を完了してください", // setup
            "保存しました", // saved
            "カメラを見てまばたきしてください", // scanning
            "パスワードを送信しました", // submitted
            "一致しませんでした。Macのパスワードを使うか、画面をスリープ解除して再試行してください。", // timeout
            "操作を完了できませんでした", // failed
            "システム設定 → プライバシーとセキュリティでカメラを許可してください。", // cameraDenied
            "選択したカメラは使用できません。接続されたカメラを選んでください。", // noCamera
            "カメラ", // camera
            "内蔵またはデフォルトのカメラ", // automatic
            "ロック画面に表示", // indicator
            "顔データとパスワードはMac内で暗号化されます。カメラの映像は保存も送信もされません。", // privacy
            "アクセス権", // permissions
            "削除", // delete
            "Glanceについて", // learnMore
            "カメラをプレビュー、または顔認証の設定後に顔の登録と認識に使います。映像は記録されず、Macの外に送信されません。", // cameraUse
        ],
        .ko: [
            "얼굴로 잠금 해제", // title
            "Glance와 카메라로 Mac의 잠금을 해제하세요.", // summary
            "웹캠은 Face ID가 아닙니다. 사진이나 동영상에 속을 수 있습니다. Glance는 잠금 화면에 저장된 Mac 암호를 입력하며, 재시작 후 FileVault를 해제하지 못합니다. 이 한계를 받아들이는 경우에만 사용하세요.", // notice
            "이해했으며 동의합니다", // accept
            "이 세션 인증", // authorize
            "앱을 시작할 때마다 인증하세요. 일시 정지하거나 종료하면 세션 키가 지워집니다.", // sessionHint
            "Mac 로그인 암호", // password
            "확인 및 저장", // save
            "얼굴 등록", // enroll
            "등록 교체", // recapture
            "밝은 곳에서 자신의 얼굴만 화면에 넣고 다섯 방향을 선명하게 촬영하세요.", // faceHint
            "정면을 보세요", // front
            "조금 왼쪽으로 돌리세요", // left
            "조금 오른쪽으로 돌리세요", // right
            "조금 위를 보세요", // up
            "조금 아래를 보세요", // down
            "얼굴 잠금 해제 켜기", // enable
            "세션 일시 정지", // pause
            "얼굴 및 암호 삭제", // forget
            "이 앱에 등록된 얼굴과 저장된 암호를 삭제할까요? 나중에 다시 설정할 수 있습니다.", // forgetConfirm
            "취소", // cancel
            "촬영", // capture
            "다음 잠금 또는 깨우기에 준비됨", // ready
            "얼굴 잠금 해제가 꺼져 있습니다", // off
            "아래 설정을 완료하세요", // setup
            "저장됨", // saved
            "카메라를 보고 눈을 깜빡이세요", // scanning
            "암호 제출됨", // submitted
            "일치하지 않습니다. Mac 암호를 사용하거나 화면을 깨워 다시 시도하세요.", // timeout
            "작업을 완료할 수 없습니다", // failed
            "시스템 설정 → 개인정보 보호 및 보안에서 카메라를 허용하세요.", // cameraDenied
            "선택한 카메라를 사용할 수 없습니다. 연결된 카메라를 선택하세요.", // noCamera
            "카메라", // camera
            "내장 또는 기본 카메라", // automatic
            "잠금 화면 표시기 표시", // indicator
            "얼굴 데이터와 암호는 로컬에서 암호화됩니다. 카메라 영상은 저장되거나 전송되지 않습니다.", // privacy
            "권한", // permissions
            "삭제", // delete
            "Glance 정보", // learnMore
            "카메라를 미리보기 또는 얼굴 잠금 해제 설정 후 얼굴 등록과 인식에 사용합니다. 영상은 기록되거나 Mac 밖으로 전송되지 않습니다.", // cameraUse
        ],
        .zhHans: [
            "面容解锁", // title
            "通过 Glance 和摄像头解锁 Mac。", // summary
            "摄像头并不等同于面容 ID，照片或视频可能骗过识别。Glance 会在锁定屏幕输入已保存的 Mac 密码，无法在重启后解锁 FileVault。仅在接受此限制时使用。", // notice
            "我已了解并接受", // accept
            "授权此会话", // authorize
            "每次启动应用后需要认证。暂停或退出会清除会话密钥。", // sessionHint
            "Mac 登录密码", // password
            "验证并保存", // save
            "录入面容", // enroll
            "重新录入", // recapture
            "在光线充足的环境中仅让自己的脸进入画面，采集五个清晰角度。", // faceHint
            "正视前方", // front
            "稍向左转", // left
            "稍向右转", // right
            "稍微抬头", // up
            "稍微低头", // down
            "启用面容解锁", // enable
            "暂停会话", // pause
            "删除面容和密码", // forget
            "删除此应用中录入的面容和保存的密码？之后可以重新设置。", // forgetConfirm
            "取消", // cancel
            "采集画面", // capture
            "已就绪，等待下次锁定或唤醒", // ready
            "面容解锁已关闭", // off
            "请完成下方设置", // setup
            "已保存", // saved
            "看向摄像头并眨眼", // scanning
            "已提交密码", // submitted
            "未匹配。请使用 Mac 密码，或唤醒屏幕后重试。", // timeout
            "无法完成操作", // failed
            "请在系统设置 → 隐私与安全性中允许摄像头访问。", // cameraDenied
            "所选摄像头不可用，请选择已连接的摄像头。", // noCamera
            "摄像头", // camera
            "内置或默认摄像头", // automatic
            "显示锁定屏幕指示器", // indicator
            "面容数据和密码在本机加密。摄像头画面不会保存或发送。", // privacy
            "权限", // permissions
            "删除", // delete
            "关于 Glance", // learnMore
            "摄像头用于预览，或在设置面容解锁后录入并识别面容。不会录制，也不会向 Mac 外发送任何内容。", // cameraUse
        ],
        .zhTW: [
            "臉部解鎖", // title
            "透過 Glance 和相機解鎖 Mac。", // summary
            "網路攝影機並不等同於 Face ID，照片或影片可能騙過辨識。Glance 會在鎖定畫面輸入已儲存的 Mac 密碼，無法在重新啟動後解鎖 FileVault。僅在接受此限制時使用。", // notice
            "我已了解並接受", // accept
            "授權此階段", // authorize
            "每次啟動 App 後需要驗證。暫停或結束會清除階段金鑰。", // sessionHint
            "Mac 登入密碼", // password
            "驗證並儲存", // save
            "登錄臉部", // enroll
            "重新登錄", // recapture
            "在光線充足的環境中只讓自己的臉進入畫面，擷取五個清晰角度。", // faceHint
            "直視前方", // front
            "稍微向左轉", // left
            "稍微向右轉", // right
            "稍微抬頭", // up
            "稍微低頭", // down
            "啟用臉部解鎖", // enable
            "暫停階段", // pause
            "刪除臉部和密碼", // forget
            "刪除此 App 中登錄的臉部和儲存的密碼？之後可以重新設定。", // forgetConfirm
            "取消", // cancel
            "擷取畫面", // capture
            "已就緒，等待下次鎖定或喚醒", // ready
            "臉部解鎖已關閉", // off
            "請完成下方設定", // setup
            "已儲存", // saved
            "看向相機並眨眼", // scanning
            "已送出密碼", // submitted
            "未符合。請使用 Mac 密碼，或喚醒螢幕後重試。", // timeout
            "無法完成操作", // failed
            "請在系統設定 → 隱私權與安全性中允許相機存取。", // cameraDenied
            "所選相機無法使用，請選擇已連接的相機。", // noCamera
            "相機", // camera
            "內建或預設相機", // automatic
            "顯示鎖定畫面指示器", // indicator
            "臉部資料和密碼在本機加密。相機畫面不會儲存或傳送。", // privacy
            "權限", // permissions
            "刪除", // delete
            "關於 Glance", // learnMore
            "相機用於預覽，或在設定臉部解鎖後登錄及辨識臉部。不會錄製，也不會向 Mac 外傳送任何內容。", // cameraUse
        ],
        .zhHK: [
            "面容解鎖", // title
            "透過 Glance 和相機解鎖 Mac。", // summary
            "網絡攝影機並不等同於 Face ID，相片或影片可能騙過辨識。Glance 會在鎖定畫面輸入已儲存的 Mac 密碼，無法在重新啟動後解鎖 FileVault。只在接受此限制時使用。", // notice
            "我已了解並接受", // accept
            "授權此階段", // authorize
            "每次啟動 App 後需要認證。暫停或結束會清除階段密鑰。", // sessionHint
            "Mac 登入密碼", // password
            "驗證並儲存", // save
            "登記面容", // enroll
            "重新登記", // recapture
            "在光線充足的環境中只讓自己的面容進入畫面，擷取五個清晰角度。", // faceHint
            "直視前方", // front
            "稍微向左轉", // left
            "稍微向右轉", // right
            "稍微抬頭", // up
            "稍微低頭", // down
            "啟用面容解鎖", // enable
            "暫停階段", // pause
            "刪除面容和密碼", // forget
            "刪除此 App 中登記的面容和儲存的密碼？之後可以重新設定。", // forgetConfirm
            "取消", // cancel
            "擷取畫面", // capture
            "已就緒，等待下次鎖定或喚醒", // ready
            "面容解鎖已關閉", // off
            "請完成下方設定", // setup
            "已儲存", // saved
            "望向相機並眨眼", // scanning
            "已提交密碼", // submitted
            "未能配對。請使用 Mac 密碼，或喚醒螢幕後重試。", // timeout
            "無法完成操作", // failed
            "請在系統設定 → 私隱與保安中允許相機取用。", // cameraDenied
            "所選相機無法使用，請選擇已連接的相機。", // noCamera
            "相機", // camera
            "內置或預設相機", // automatic
            "顯示鎖定畫面指示器", // indicator
            "面容資料和密碼在本機加密。相機畫面不會儲存或傳送。", // privacy
            "權限", // permissions
            "刪除", // delete
            "關於 Glance", // learnMore
            "相機用於預覽，或在設定面容解鎖後登記及辨識面容。不會錄製，也不會向 Mac 外傳送任何內容。", // cameraUse
        ],
        .ru: [
            "Разблокировка по лицу", // title
            "Разблокируйте Mac с помощью Glance и камеры.", // summary
            "Веб-камера — не Face ID. Фото или видео могут её обмануть. Glance вводит сохранённый пароль Mac на экране блокировки; FileVault после перезагрузки не разблокируется. Используйте функцию, только если принимаете это ограничение.", // notice
            "Понимаю и принимаю", // accept
            "Авторизовать сеанс", // authorize
            "Подтверждайте доступ после каждого запуска приложения. Пауза или выход удаляют ключ сеанса из памяти.", // sessionHint
            "Пароль входа на Mac", // password
            "Проверить и сохранить", // save
            "Зарегистрировать лицо", // enroll
            "Заменить регистрацию", // recapture
            "При хорошем освещении оставьте в кадре только своё лицо. Сделайте пять чётких снимков.", // faceHint
            "Смотрите прямо", // front
            "Немного повернитесь влево", // left
            "Немного повернитесь вправо", // right
            "Немного поднимите голову", // up
            "Немного опустите голову", // down
            "Включить разблокировку по лицу", // enable
            "Приостановить сеанс", // pause
            "Удалить лицо и пароль", // forget
            "Удалить лицо и сохранённый пароль из этого приложения? Их можно настроить заново.", // forgetConfirm
            "Отмена", // cancel
            "Сделать снимок", // capture
            "Готово к следующей блокировке или пробуждению", // ready
            "Разблокировка по лицу выключена", // off
            "Завершите настройку ниже", // setup
            "Сохранено", // saved
            "Посмотрите в камеру и моргните", // scanning
            "Пароль отправлен", // submitted
            "Нет совпадения. Введите пароль Mac или пробудите экран для повтора.", // timeout
            "Не удалось завершить операцию", // failed
            "Разрешите камеру: Системные настройки → Конфиденциальность и безопасность.", // cameraDenied
            "Выбранная камера недоступна. Выберите подключённую камеру.", // noCamera
            "Камера", // camera
            "Встроенная камера или камера по умолчанию", // automatic
            "Индикатор на экране блокировки", // indicator
            "Данные лица и пароль зашифрованы локально. Кадры камеры не сохраняются и не отправляются.", // privacy
            "Разрешения", // permissions
            "Удалить", // delete
            "О Glance", // learnMore
            "Камера используется для предпросмотра или, после настройки разблокировки, для регистрации и распознавания лица. Ничего не записывается и не отправляется с Mac.", // cameraUse
        ],
        .uk: [
            "Розблокування обличчям", // title
            "Розблокуйте Mac за допомогою Glance і камери.", // summary
            "Вебкамера — не Face ID. Фото чи відео можуть її обманути. Glance вводить збережений пароль Mac на екрані блокування; FileVault після перезапуску не розблокується. Використовуйте функцію, лише якщо приймаєте це обмеження.", // notice
            "Розумію та приймаю", // accept
            "Авторизувати сеанс", // authorize
            "Підтверджуйте доступ після кожного запуску програми. Пауза або вихід очищують ключ сеансу з пам’яті.", // sessionHint
            "Пароль входу на Mac", // password
            "Перевірити й зберегти", // save
            "Зареєструвати обличчя", // enroll
            "Замінити реєстрацію", // recapture
            "За доброго освітлення залиште в кадрі лише своє обличчя. Зробіть п’ять чітких знімків.", // faceHint
            "Дивіться прямо", // front
            "Трохи поверніться ліворуч", // left
            "Трохи поверніться праворуч", // right
            "Трохи підніміть голову", // up
            "Трохи опустіть голову", // down
            "Увімкнути розблокування обличчям", // enable
            "Призупинити сеанс", // pause
            "Видалити обличчя та пароль", // forget
            "Видалити обличчя і збережений пароль із цієї програми? Їх можна налаштувати знову.", // forgetConfirm
            "Скасувати", // cancel
            "Зробити знімок", // capture
            "Готово до наступного блокування чи пробудження", // ready
            "Розблокування обличчям вимкнено", // off
            "Завершіть налаштування нижче", // setup
            "Збережено", // saved
            "Подивіться в камеру та моргніть", // scanning
            "Пароль надіслано", // submitted
            "Немає збігу. Введіть пароль Mac або пробудіть екран для повтору.", // timeout
            "Не вдалося завершити операцію", // failed
            "Дозвольте камеру: Системні параметри → Приватність і безпека.", // cameraDenied
            "Вибрана камера недоступна. Виберіть підключену камеру.", // noCamera
            "Камера", // camera
            "Вбудована або типова камера", // automatic
            "Індикатор на екрані блокування", // indicator
            "Дані обличчя й пароль зашифровано локально. Кадри камери не зберігаються і не надсилаються.", // privacy
            "Дозволи", // permissions
            "Видалити", // delete
            "Про Glance", // learnMore
            "Камера використовується для перегляду або, після налаштування розблокування, для реєстрації та розпізнавання обличчя. Нічого не записується і не надсилається з Mac.", // cameraUse
        ],
        .sk: [
            "Odomknutie tvárou", // title
            "Odomknite Mac pomocou Glance a kamery.", // summary
            "Webkamera nie je Face ID. Fotografie alebo videá ju môžu oklamať. Glance zadáva uložené heslo Macu na zamknutej obrazovke; po reštarte neodomkne FileVault. Používajte len vtedy, ak toto obmedzenie prijímate.", // notice
            "Rozumiem a súhlasím", // accept
            "Autorizovať reláciu", // authorize
            "Overte sa po každom spustení apky. Pozastavenie alebo ukončenie vymaže kľúč relácie.", // sessionHint
            "Prihlasovacie heslo Macu", // password
            "Overiť a uložiť", // save
            "Zaregistrovať tvár", // enroll
            "Nahradiť registráciu", // recapture
            "Pri dobrom svetle nechajte v zábere len svoju tvár. Zachyťte päť jasných pohľadov.", // faceHint
            "Pozerajte sa rovno", // front
            "Otočte sa mierne doľava", // left
            "Otočte sa mierne doprava", // right
            "Mierne zdvihnite hlavu", // up
            "Mierne skloňte hlavu", // down
            "Zapnúť odomknutie tvárou", // enable
            "Pozastaviť reláciu", // pause
            "Zabudnúť tvár a heslo", // forget
            "Vymazať tvár a uložené heslo z tejto apky? Neskôr ich môžete nastaviť znova.", // forgetConfirm
            "Zrušiť", // cancel
            "Zachytiť pohľad", // capture
            "Pripravené na ďalšie zamknutie alebo prebudenie", // ready
            "Odomknutie tvárou je vypnuté", // off
            "Dokončite nastavenie nižšie", // setup
            "Uložené", // saved
            "Pozrite sa do kamery a žmurknite", // scanning
            "Heslo odoslané", // submitted
            "Bez zhody. Použite heslo Macu alebo prebuďte displej a skúste znova.", // timeout
            "Operáciu sa nepodarilo dokončiť", // failed
            "Povoľte kameru v Systémové nastavenia → Súkromie a bezpečnosť.", // cameraDenied
            "Vybraná kamera nie je dostupná. Vyberte pripojenú kameru.", // noCamera
            "Kamera", // camera
            "Vstavaná alebo predvolená kamera", // automatic
            "Zobraziť indikátor na zamknutej obrazovke", // indicator
            "Údaje tváre a heslo sú šifrované lokálne. Snímky kamery sa neukladajú ani neposielajú.", // privacy
            "Povolenia", // permissions
            "Vymazať", // delete
            "O Glance", // learnMore
            "Kamera slúži na náhľad alebo po nastavení odomknutia na registráciu a rozpoznanie tváre. Nič sa nenahráva ani neposiela z Macu.", // cameraUse
        ],
        .tr: [
            "Yüzle kilit açma", // title
            "Glance ve kameranızla Mac’inizin kilidini açın.", // summary
            "Web kamerası Face ID değildir. Fotoğraf veya videolar sistemi yanıltabilir. Glance, kayıtlı Mac parolanızı kilit ekranına yazar; yeniden başlatmadan sonra FileVault’u açamaz. Yalnızca bu sınırlamayı kabul ediyorsanız kullanın.", // notice
            "Anladım ve kabul ediyorum", // accept
            "Bu oturumu yetkilendir", // authorize
            "Uygulamayı her açtığınızda kimliğinizi doğrulayın. Duraklatmak veya çıkmak oturum anahtarını siler.", // sessionHint
            "Mac oturum açma parolası", // password
            "Doğrula ve kaydet", // save
            "Yüzünüzü kaydedin", // enroll
            "Kaydı değiştir", // recapture
            "İyi ışıkta yalnızca yüzünüzü kadraja alın. Beş net açı yakalayın.", // faceHint
            "Karşıya bakın", // front
            "Biraz sola dönün", // left
            "Biraz sağa dönün", // right
            "Başınızı biraz kaldırın", // up
            "Başınızı biraz eğin", // down
            "Yüzle kilit açmayı etkinleştir", // enable
            "Oturumu duraklat", // pause
            "Yüzü ve parolayı unut", // forget
            "Bu uygulamadaki yüz kaydı ve parola silinsin mi? Daha sonra yeniden ayarlayabilirsiniz.", // forgetConfirm
            "İptal", // cancel
            "Görüntü yakala", // capture
            "Sonraki kilit veya uyanma için hazır", // ready
            "Yüzle kilit açma kapalı", // off
            "Aşağıdaki kurulumu tamamlayın", // setup
            "Kaydedildi", // saved
            "Kameraya bakın ve göz kırpın", // scanning
            "Parola gönderildi", // submitted
            "Eşleşme yok. Mac parolanızı kullanın veya yeniden denemek için ekranı uyandırın.", // timeout
            "İşlem tamamlanamadı", // failed
            "Sistem Ayarları → Gizlilik ve Güvenlik’te Kamera’ya izin verin.", // cameraDenied
            "Seçili kamera kullanılamıyor. Bağlı bir kamera seçin.", // noCamera
            "Kamera", // camera
            "Yerleşik veya varsayılan kamera", // automatic
            "Kilit ekranı göstergesini göster", // indicator
            "Yüz verileri ve parola yerel olarak şifrelenir. Kamera görüntüleri kaydedilmez veya gönderilmez.", // privacy
            "İzinler", // permissions
            "Sil", // delete
            "Glance hakkında", // learnMore
            "Kamera önizleme için veya yüzle kilit açma ayarlandıktan sonra yüzünüzü kaydetmek ve tanımak için kullanılır. Hiçbir şey kaydedilmez veya Mac’inizden gönderilmez.", // cameraUse
        ],
    ]
}
