<?php

const AUTH_KEY_PATH = '/Path/to/AuthKey_keyid.p8';
const AUTH_KEY_ID = '';
const TEAM_ID = '';
const BUNDLE_ID = 'com.raywenderlich.APNS';
const PDO_CONN_STR = 'pgsql:host=localhost;dbname=mySqlDatabase;user=mySqlUser;password=myStrongPassword';

$payload = [
    'aps' => [
        'alert'    => [
            'title' => 'This is the notification.',
        ],
        'sound'    => 'default',
        #'category' => 'Timer'
    ],
];

/**
 * Determines which tokens that are registered with our application should
 * have a push notification sent to them.
 *
 * @param PDO $db The connected database connection.
 *
 * @return string[] A list of APNS tokens.
 */
function tokensToReceiveNotification(PDO $db)
{
    $stmt = $db->prepare('SELECT DISTINCT token FROM apns');
    $stmt->execute();

    return $stmt->fetchAll(PDO::FETCH_COLUMN, 0);
}

# ---- No changes should be required below this line ----

$db = new PDO(PDO_CONN_STR);

function generateAuthenticationHeader()
{
    $header = base64_encode(json_encode(['alg' => 'ES256', 'kid' => AUTH_KEY_ID]));
    $claims = base64_encode(json_encode(['iss' => TEAM_ID, 'iat' => time()]));

    $pkey = openssl_pkey_get_private('file://' . AUTH_KEY_PATH);
    openssl_sign("$header.$claims", $signature, $pkey, 'sha256');

    $signed = base64_encode($signature);

    return "$header.$claims.$signed";
}

$ch = curl_init();
curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'apns-topic: ' . BUNDLE_ID,
    'Authorization: Bearer ' . generateAuthenticationHeader()
]);

$removeToken = $db->prepare('DELETE FROM apns WHERE token = ?');

foreach (tokensToReceiveNotification($db) as $token) {
    $url = "https://api.development.push.apple.com/3/device/$token";
    curl_setopt($ch, CURLOPT_URL, "{$url}");

    $response = curl_exec($ch);
    if ($response === false) {
        echo("curl_exec failed: " . curl_error($ch));
        continue;
    }

    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    if ($code === 400 && $response === 'BadDeviceToken') {
        $removeToken->execute([$token]);
    }
}

curl_close($ch);
