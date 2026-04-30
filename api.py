import os, json
from flask import Flask, request, jsonify
from flask_cors import CORS
import yfinance as yf
import anthropic

app = Flask(__name__)
CORS(app)  # allow requests from GitHub Pages + ngrok

# yfinance symbol overrides for commodities
SYMBOL_MAP = {
    "XAUUSD": "GC=F",   # Gold futures
    "USOIL":  "CL=F",   # Crude Oil WTI
    "UKOIL":  "BZ=F",   # Brent Oil
}

def rsi(prices, period=14):
    delta = prices.diff()
    gain  = delta.where(delta > 0, 0).rolling(period).mean()
    loss  = (-delta.where(delta < 0, 0)).rolling(period).mean()
    rs    = gain / loss
    return round(float((100 - 100 / (1 + rs)).iloc[-1]), 2)

def macd(prices):
    ema12 = prices.ewm(span=12, adjust=False).mean()
    ema26 = prices.ewm(span=26, adjust=False).mean()
    return round(float((ema12 - ema26).iloc[-1]), 6)

@app.route("/", methods=["POST", "OPTIONS"])
def signal():
    if request.method == "OPTIONS":
        return jsonify({}), 200

    body   = request.get_json(force=True)
    symbol = body.get("symbol", "")
    label  = body.get("label", symbol)

    # Map to yfinance symbol if needed
    yf_sym = SYMBOL_MAP.get(symbol, symbol)

    # --- Fetch price data ---
    try:
        hist  = yf.Ticker(yf_sym).history(period="6mo", interval="1d")
        if hist.empty:
            raise ValueError("Empty data")
        close = hist["Close"]
    except Exception as e:
        return jsonify({"error": f"Data fetch failed: {e}"}), 500

    price_val = round(float(close.iloc[-1]), 5)
    rsi_val   = rsi(close)
    macd_val  = macd(close)

    # --- Ask Claude for signal ---
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return jsonify({"error": "ANTHROPIC_API_KEY not set"}), 500

    client = anthropic.Anthropic(api_key=api_key)

    prompt = f"""You are a professional trading analyst. Analyze {label} and give a trading signal.

Live Data:
  Symbol : {symbol}
  Price  : {price_val}
  RSI(14): {rsi_val}
  MACD   : {macd_val}

Reply with ONLY a JSON object — no markdown, no explanation — using these exact keys:
{{
  "signal":      "BUY" | "SELL" | "WAIT",
  "entry":       "<price or range as string>",
  "stop_loss":   "<price as string>",
  "take_profit": "<price as string>",
  "reason":      "<2-3 sentence analysis>",
  "confidence":  "low" | "medium" | "high"
}}"""

    try:
        msg    = client.messages.create(
            model="claude-opus-4-5",
            max_tokens=512,
            messages=[{"role": "user", "content": prompt}],
        )
        result = json.loads(msg.content[0].text)
    except Exception as e:
        return jsonify({"error": f"Claude API error: {e}"}), 500

    result["price"] = str(price_val)
    result["rsi"]   = str(rsi_val)
    result["macd"]  = str(macd_val)

    return jsonify(result)

if __name__ == "__main__":
    print("AI Signal Desk backend running on http://0.0.0.0:5000")
    app.run(host="0.0.0.0", port=5000, debug=False)
