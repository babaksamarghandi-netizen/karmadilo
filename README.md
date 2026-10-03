# Karmadilo

Flutter dashboard for Karmadilo.

## Current stage

The dashboard now requests live market quotes when it opens:

- USD / Iranian rial market price
- 18-carat gold
- Bitcoin (BTC/USD)

Iranian market quotes are fetched from TGJU's market-data endpoint. Bitcoin uses CoinGecko's public market endpoint. The app converts Iranian-rial quotes to toman for display.

The app also supports pull-to-refresh on the dashboard.

## Build

GitHub Actions generates the Android project and builds the release APK.
