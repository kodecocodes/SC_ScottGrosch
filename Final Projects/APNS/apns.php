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

foreach (['token', 'data', 'debug'] as $key) {
    if (!array_key_exists($key, $json)) {
        http_response_code(400);
        exit;
    }
}

if (!is_object($json->data)) {
    http_response_code(400);
    exit;
}

$db = new PDO('pgsql:host=localhost;dbname=apns;user=apns;password=apns');

$token = $json->token;
$debug = $json->debug;

$db->prepare('DELETE FROM apns WHERE token = ?')->execute([$token]);

$stmt = $db->prepare('INSERT INTO apns (token, type, debug, dates) VALUES (?, ?, ?, ?::daterange)');

foreach ($json->data as $type => $dates) {
    foreach ($dates as $date) {
        $stmt->execute([$token, $type, $debug ? 't' : 'f', $date]);
    }
}

