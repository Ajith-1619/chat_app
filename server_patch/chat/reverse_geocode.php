<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

chat_require_user();
$lat = isset($_GET['lat']) && is_numeric($_GET['lat']) ? (float)$_GET['lat'] : null;
$lon = isset($_GET['lon']) && is_numeric($_GET['lon']) ? (float)$_GET['lon'] : null;
if ($lat === null || $lon === null) {
    chat_json(['status' => false, 'error' => 'Latitude and longitude are required'], 422);
}

$fallback = 'Location unavailable';
$apiKey = getenv('GOOGLE_MAPS_API_KEY') ?: (defined('GOOGLE_MAPS_API_KEY') ? (string)GOOGLE_MAPS_API_KEY : 'AIzaSyDdDoEaS6QDSnA6yB5PUeEf4l5BH7kMEA8');
if ($apiKey === '') {
    chat_json(['status' => true, 'address' => $fallback, 'provider' => 'coordinates']);
}

$url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=' .
    rawurlencode($lat . ',' . $lon) . '&key=' . rawurlencode($apiKey);
$context = stream_context_create(['http' => ['timeout' => 4]]);
$raw = @file_get_contents($url, false, $context);
if ($raw === false) {
    chat_json(['status' => true, 'address' => $fallback, 'provider' => 'coordinates']);
}
$json = json_decode($raw, true);
$address = '';
if (is_array($json) && (($json['status'] ?? '') === 'OK') && !empty($json['results'][0]['formatted_address'])) {
    $address = (string)$json['results'][0]['formatted_address'];
}
chat_json([
    'status' => true,
    'address' => $address !== '' ? $address : $fallback,
    'provider' => $address !== '' ? 'google' : 'coordinates',
]);
