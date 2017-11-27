<?php

if (!isset($_SERVER['CONTENT_TYPE']) || strcasecmp($_SERVER['CONTENT_TYPE'], 'application/json')) {
    http_response_code(415);
    exit;
}


if (($stream = @fopen('php://input', 'r')) === false) {
    http_response_code(400);
    exit;
}

$contents = stream_get_contents($stream);
$json = @json_decode($contents);
@fclose($stream);

foreach (['ident', 'ios', 'app', 'languages'] as $key) {
    if (!array_key_exists($key, $json)) {
        http_response_code(400);
        exit;
    }
}

$db = new PDO('pgsql:host=localhost;dbname=mySqlDatabase;user=mySqlUser;password=myStrongPassword');

$db->prepare('DELETE FROM info WHERE ident = ? AND app = ?')->execute([$json->ident, $json->app]);

$stmt = $db->prepare('INSERT INTO info (ident, app, languages, ios) VALUES (?, ?, ?, ?)');
$stmt->execute([$json->ident, $json->app, $json->languages, $json->ios]);

