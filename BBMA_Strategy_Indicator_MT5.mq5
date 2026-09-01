//+------------------------------------------------------------------+
//|                  BBMA Strategy Indicator MT5 v3.1                |
//|            Optimized untuk 15M dengan Multi-Confirmation          |
//|         Sinyal akurat dengan Filter Noise dan Volume              |
//+------------------------------------------------------------------+
#property copyright "Trading Strategy"
#property link      "https://github.com/Ahmad112005"
#property version   "3.10"
#property strict
#property indicator_chart_window

#property indicator_buffers 12
#property indicator_plots 7

// Plotting properties
#property indicator_label1  "BB Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_width1  1
#property indicator_style1  STYLE_SOLID

#property indicator_label2  "BB Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_width2  1
#property indicator_style2  STYLE_SOLID

#property indicator_label3  "BB Middle"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_width3  1
#property indicator_style3  STYLE_DASH

#property indicator_label4  "EMA 9"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrBlue
#property indicator_width4  2
#property indicator_style4  STYLE_SOLID

#property indicator_label5  "EMA 21"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrange
#property indicator_width5  2
#property indicator_style5  STYLE_SOLID

#property indicator_label6  "RSI"
#property indicator_type6   DRAW_NONE
#property indicator_color6  clrWhite

#property indicator_label7  "Buy/Sell Signal"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrYellow
#property indicator_width7  3

// Input parameters
input int         BB_Period         = 20;           // Bollinger Bands Period
input double      BB_StdDev         = 2.0;          // Standard Deviation
input int         MA_Period_Fast    = 9;            // EMA 9 Period
input int         MA_Period_Slow    = 21;           // EMA 21 Period
input int         RSI_Period        = 14;           // RSI Period
input int         ATR_Period        = 14;           // ATR Period
input double      SL_Multiplier     = 1.5;          // Stop Loss Multiplier
input double      TP_Multiplier     = 2.5;          // Take Profit Multiplier
input double      Min_Volume_Ratio  = 1.2;          // Minimum Volume Ratio for Signal
input bool        ShowAlerts        = true;         // Show Alerts
input bool        ShowComments      = true;         // Show Chart Comments
input int         Signal_Strength   = 2;            // 1=Aggressive, 2=Normal, 3=Conservative

// Indicator buffers
double BB_Upper_Buffer[];
double BB_Lower_Buffer[];
double BB_Middle_Buffer[];
double EMA9_Buffer[];
double EMA21_Buffer[];
double RSI_Buffer[];
double ATR_Buffer[];
double Volume_MA_Buffer[];
double Signal_Buffer_Arrows[];
double Signal_Confidence[];
double MACD_Buffer[];
double Signal_Line_Buffer[];

// Global variables
datetime last_alert_time = 0;
int last_signal = 0;
double last_alert_price = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, BB_Upper_Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, BB_Lower_Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, BB_Middle_Buffer, INDICATOR_DATA);
    SetIndexBuffer(3, EMA9_Buffer, INDICATOR_DATA);
    SetIndexBuffer(4, EMA21_Buffer, INDICATOR_DATA);
    SetIndexBuffer(5, RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(6, Signal_Buffer_Arrows, INDICATOR_DATA);
    SetIndexBuffer(7, ATR_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(8, Volume_MA_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(9, Signal_Confidence, INDICATOR_CALCULATIONS);
    SetIndexBuffer(10, MACD_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(11, Signal_Line_Buffer, INDICATOR_CALCULATIONS);
    
    IndicatorSetString(INDICATOR_SHORTNAME, "BBMA Strategy v3.10 (15M) - Multi-Confirmation");
    
    ArraySetAsSeries(BB_Upper_Buffer, true);
    ArraySetAsSeries(BB_Lower_Buffer, true);
    ArraySetAsSeries(BB_Middle_Buffer, true);
    ArraySetAsSeries(EMA9_Buffer, true);
    ArraySetAsSeries(EMA21_Buffer, true);
    ArraySetAsSeries(RSI_Buffer, true);
    ArraySetAsSeries(ATR_Buffer, true);
    ArraySetAsSeries(Volume_MA_Buffer, true);
    ArraySetAsSeries(Signal_Buffer_Arrows, true);
    ArraySetAsSeries(Signal_Confidence, true);
    ArraySetAsSeries(MACD_Buffer, true);
    ArraySetAsSeries(Signal_Line_Buffer, true);
    
    PlotIndexSetInteger(6, PLOT_ARROW, 233);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(tick_volume, true);
    ArraySetAsSeries(volume, true);
    
    int start = prev_calculated - 1;
    if(start < 0) start = 0;
    
    for(int i = start; i < rates_total; i++)
    {
        CalculateBollingerBands(i, close, rates_total);
        CalculateEMA(i, close, MA_Period_Fast, EMA9_Buffer);
        CalculateEMA(i, close, MA_Period_Slow, EMA21_Buffer);
        CalculateRSI(i, close, rates_total);
        CalculateMACD(i, close, rates_total);
        CalculateATR(i, high, low, close, rates_total);
        CalculateVolumeMA(i, volume, 20);
        
        if(i > BB_Period + MA_Period_Slow + 30)
        {
            GenerateSignal(i, open, high, low, close, tick_volume, time);
        }
    }
    
    if(ShowComments)
    {
        DisplayChartInfo(rates_total, close, time);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Bollinger Bands                                        |
//+------------------------------------------------------------------+
void CalculateBollingerBands(int index, const double &close[], int rates_total)
{
    if(index < BB_Period - 1)
    {
        BB_Upper_Buffer[index] = 0;
        BB_Lower_Buffer[index] = 0;
        BB_Middle_Buffer[index] = 0;
        return;
    }
    
    double sum = 0;
    for(int i = 0; i < BB_Period; i++)
        sum += close[index + i];
    
    double sma = sum / BB_Period;
    BB_Middle_Buffer[index] = sma;
    
    double sum_sq = 0;
    for(int i = 0; i < BB_Period; i++)
    {
        double diff = close[index + i] - sma;
        sum_sq += diff * diff;
    }
    
    double stddev = MathSqrt(sum_sq / BB_Period);
    BB_Upper_Buffer[index] = sma + (stddev * BB_StdDev);
    BB_Lower_Buffer[index] = sma - (stddev * BB_StdDev);
}

//+------------------------------------------------------------------+
//| Calculate EMA                                                    |
//+------------------------------------------------------------------+
void CalculateEMA(int index, const double &close[], int period, double &ema_buffer[])
{
    if(index < period - 1)
    {
        if(index == period - 1)
        {
            double sum = 0;
            for(int i = 0; i < period; i++)
                sum += close[index + i];
            ema_buffer[index] = sum / period;
        }
        else
            ema_buffer[index] = 0;
        return;
    }
    
    double multiplier = 2.0 / (period + 1.0);
    ema_buffer[index] = close[index] * multiplier + ema_buffer[index + 1] * (1.0 - multiplier);
}

//+------------------------------------------------------------------+
//| Calculate RSI                                                    |
//+------------------------------------------------------------------+
void CalculateRSI(int index, const double &close[], int rates_total)
{
    if(index < RSI_Period + 1)
    {
        RSI_Buffer[index] = 50;
        return;
    }
    
    double gain_sum = 0, loss_sum = 0;
    
    for(int i = 0; i < RSI_Period; i++)
    {
        double change = close[index + i] - close[index + i + 1];
        if(change > 0)
            gain_sum += change;
        else
            loss_sum += -change;
    }
    
    double avg_gain = gain_sum / RSI_Period;
    double avg_loss = loss_sum / RSI_Period;
    
    double rs = (avg_loss != 0) ? avg_gain / avg_loss : 0;
    RSI_Buffer[index] = 100.0 - (100.0 / (1.0 + rs));
}

//+------------------------------------------------------------------+
//| Calculate MACD                                                   |
//+------------------------------------------------------------------+
void CalculateMACD(int index, const double &close[], int rates_total)
{
    if(index < 26)
    {
        MACD_Buffer[index] = 0;
        Signal_Line_Buffer[index] = 0;
        return;
    }
    
    double ema12 = CalculateSimpleEMA(index, close, 12);
    double ema26 = CalculateSimpleEMA(index, close, 26);
    MACD_Buffer[index] = ema12 - ema26;
    
    if(index < 33)
        Signal_Line_Buffer[index] = 0;
    else
        Signal_Line_Buffer[index] = CalculateSimpleEMA(index, MACD_Buffer, 9);
}

//+------------------------------------------------------------------+
//| Calculate Simple EMA Helper                                      |
//+------------------------------------------------------------------+
double CalculateSimpleEMA(int index, const double &data[], int period)
{
    if(index < period - 1)
        return 0;
    
    if(index == period - 1)
    {
        double sum = 0;
        for(int i = 0; i < period; i++)
            sum += data[index + i];
        return sum / period;
    }
    
    double multiplier = 2.0 / (period + 1.0);
    return data[index] * multiplier + CalculateSimpleEMA(index + 1, data, period) * (1.0 - multiplier);
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                    |
//+------------------------------------------------------------------+
void CalculateATR(int index, const double &high[], const double &low[], const double &close[], int rates_total)
{
    if(index < ATR_Period - 1)
    {
        ATR_Buffer[index] = 0;
        return;
    }
    
    double tr = 0;
    double high_low = high[index] - low[index];
    double high_close = MathAbs(high[index] - close[index + 1]);
    double low_close = MathAbs(low[index] - close[index + 1]);
    
    tr = MathMax(high_low, MathMax(high_close, low_close));
    
    if(index == ATR_Period - 1)
    {
        double sum = 0;
        for(int i = 0; i < ATR_Period; i++)
        {
            double hl = high[index + i] - low[index + i];
            double hc = MathAbs(high[index + i] - close[index + i + 1]);
            double lc = MathAbs(low[index + i] - close[index + i + 1]);
            double tr_temp = MathMax(hl, MathMax(hc, lc));
            sum += tr_temp;
        }
        ATR_Buffer[index] = sum / ATR_Period;
    }
    else if(index > ATR_Period - 1)
    {
        ATR_Buffer[index] = (ATR_Buffer[index + 1] * (ATR_Period - 1) + tr) / ATR_Period;
    }
}

//+------------------------------------------------------------------+
//| Calculate Volume MA - Fixed type conversion warning              |
//+------------------------------------------------------------------+
void CalculateVolumeMA(int index, const long &volume[], int period)
{
    if(index < period - 1)
    {
        Volume_MA_Buffer[index] = 0;
        return;
    }
    
    double sum = 0.0;
    for(int i = 0; i < period; i++)
    {
        sum += (double)volume[index + i];  // Explicit cast from long to double
    }
    
    Volume_MA_Buffer[index] = sum / period;
}

//+------------------------------------------------------------------+
//| Check Signal Strength                                            |
//+------------------------------------------------------------------+
int CheckSignalConfirmation(int index, const double &open[], const double &high[], 
                            const double &low[], const double &close[], 
                            const long &volume[], bool is_buy)
{
    int confirmation_count = 0;
    
    double current_price = close[index];
    double prev_price = close[index + 1];
    double prev2_price = close[index + 2];
    
    double ema9 = EMA9_Buffer[index];
    double ema21 = EMA21_Buffer[index];
    double bb_upper = BB_Upper_Buffer[index];
    double bb_lower = BB_Lower_Buffer[index];
    double bb_middle = BB_Middle_Buffer[index];
    
    double rsi = RSI_Buffer[index];
    double prev_rsi = RSI_Buffer[index + 1];
    
    double macd = MACD_Buffer[index];
    double macd_prev = MACD_Buffer[index + 1];
    double signal_line = Signal_Line_Buffer[index];
    double signal_prev = Signal_Line_Buffer[index + 1];
    
    double current_volume = (double)volume[index];  // Explicit cast from long to double
    double prev_volume = (double)volume[index + 1];  // Explicit cast from long to double
    double volume_ma = Volume_MA_Buffer[index];
    
    double atr = ATR_Buffer[index];
    double bb_width = bb_upper - bb_lower;
    
    // Konfirmasi 1: EMA Position (Trend)
    if(is_buy && ema9 > ema21)
        confirmation_count++;
    else if(!is_buy && ema9 < ema21)
        confirmation_count++;
    
    // Konfirmasi 2: Bollinger Bands Position
    if(is_buy && current_price <= bb_middle && prev_price >= bb_middle)
        confirmation_count++;
    else if(!is_buy && current_price >= bb_middle && prev_price <= bb_middle)
        confirmation_count++;
    
    // Konfirmasi 3: Price Action (Rebound/Rejection)
    if(is_buy && low[index] < bb_lower && close[index] > open[index])
        confirmation_count++;
    else if(!is_buy && high[index] > bb_upper && close[index] < open[index])
        confirmation_count++;
    
    // Konfirmasi 4: RSI Confirmation
    if(is_buy && rsi < 50 && rsi > 20)
        confirmation_count++;
    else if(!is_buy && rsi > 50 && rsi < 80)
        confirmation_count++;
    
    // Konfirmasi 5: MACD Confirmation
    if(is_buy && macd_prev < signal_prev && macd > signal_line)
        confirmation_count++;
    else if(!is_buy && macd_prev > signal_prev && macd < signal_line)
        confirmation_count++;
    
    // Konfirmasi 6: Volume Confirmation
    if(current_volume > (volume_ma * Min_Volume_Ratio))
        confirmation_count++;
    
    // Konfirmasi 7: Candlestick Pattern (Engulfing atau Pin Bar)
    double body_size = MathAbs(close[index] - open[index]);
    double prev_body_size = MathAbs(close[index + 1] - open[index + 1]);
    
    if(is_buy && body_size > prev_body_size && close[index] > open[index])
        confirmation_count++;
    else if(!is_buy && body_size > prev_body_size && close[index] < open[index])
        confirmation_count++;
    
    return confirmation_count;
}

//+------------------------------------------------------------------+
//| Generate Buy/Sell Signals dengan Multi-Confirmation              |
//+------------------------------------------------------------------+
void GenerateSignal(int index, const double &open[], const double &high[], 
                    const double &low[], const double &close[], 
                    const long &volume[], const datetime &time[])
{
    Signal_Buffer_Arrows[index] = 0;
    Signal_Confidence[index] = 0;
    
    if(index < 2) return;
    
    double current_price = close[index];
    double prev_price = close[index + 1];
    double prev2_price = close[index + 2];
    
    double bb_upper = BB_Upper_Buffer[index];
    double bb_lower = BB_Lower_Buffer[index];
    double bb_middle = BB_Middle_Buffer[index];
    
    double ema9 = EMA9_Buffer[index];
    double ema21 = EMA21_Buffer[index];
    
    double rsi = RSI_Buffer[index];
    double macd = MACD_Buffer[index];
    double signal_line = Signal_Line_Buffer[index];
    
    double atr = ATR_Buffer[index];
    
    if(bb_upper <= 0 || bb_lower <= 0 || ema9 <= 0 || atr <= 0)
        return;
    
    // ==================== BUY SIGNAL ====================
    int buy_confirmations = CheckSignalConfirmation(index, open, high, low, close, volume, true);
    int buy_threshold = (Signal_Strength == 1) ? 4 : (Signal_Strength == 2) ? 5 : 6;
    
    bool buy_signal = (buy_confirmations >= buy_threshold) && 
                      (current_price > bb_lower * 1.005) &&
                      (ema9 > ema21) &&
                      (rsi < 70);
    
    // ==================== SELL SIGNAL ====================
    int sell_confirmations = CheckSignalConfirmation(index, open, high, low, close, volume, false);
    int sell_threshold = (Signal_Strength == 1) ? 4 : (Signal_Strength == 2) ? 5 : 6;
    
    bool sell_signal = (sell_confirmations >= sell_threshold) && 
                       (current_price < bb_upper * 0.995) &&
                       (ema9 < ema21) &&
                       (rsi > 30);
    
    // Filter untuk menghindari signal terlalu dekat
    bool distance_ok = (MathAbs(current_price - last_alert_price) > (atr * 0.5));
    
    if(buy_signal && distance_ok)
    {
        Signal_Buffer_Arrows[index] = current_price - atr;
        Signal_Confidence[index] = buy_confirmations;
        last_signal = 1;
        last_alert_price = current_price;
        
        if(ShowAlerts && time[index] != last_alert_time)
        {
            double stop_loss = current_price - (atr * SL_Multiplier);
            double take_profit = current_price + (atr * TP_Multiplier);
            double risk_reward = (take_profit - current_price) / (current_price - stop_loss);
            
            string strength = (buy_confirmations >= 6) ? "STRONG" : "NORMAL";
            string alert_msg = StringFormat(
                "🟢 %s BUY SIGNAL\nSymbol: %s | Time: %s\nEntry: %.5f\nStop Loss: %.5f\nTake Profit: %.5f\nR/R: %.2f\nConfirmation: %d/7\nRSI: %.2f | EMA9>EMA21",
                strength, Symbol(), TimeToString(time[index], TIME_DATE|TIME_MINUTES),
                current_price, stop_loss, take_profit, risk_reward, buy_confirmations, rsi
            );
            
            Alert(alert_msg);
            Print(alert_msg);
            last_alert_time = time[index];
        }
    }
    else if(sell_signal && distance_ok)
    {
        Signal_Buffer_Arrows[index] = current_price + atr;
        Signal_Confidence[index] = -sell_confirmations;
        last_signal = -1;
        last_alert_price = current_price;
        
        if(ShowAlerts && time[index] != last_alert_time)
        {
            double stop_loss = current_price + (atr * SL_Multiplier);
            double take_profit = current_price - (atr * TP_Multiplier);
            double risk_reward = (current_price - take_profit) / (stop_loss - current_price);
            
            string strength = (sell_confirmations >= 6) ? "STRONG" : "NORMAL";
            string alert_msg = StringFormat(
                "🔴 %s SELL SIGNAL\nSymbol: %s | Time: %s\nEntry: %.5f\nStop Loss: %.5f\nTake Profit: %.5f\nR/R: %.2f\nConfirmation: %d/7\nRSI: %.2f | EMA9<EMA21",
                strength, Symbol(), TimeToString(time[index], TIME_DATE|TIME_MINUTES),
                current_price, stop_loss, take_profit, risk_reward, sell_confirmations, rsi
            );
            
            Alert(alert_msg);
            Print(alert_msg);
            last_alert_time = time[index];
        }
    }
}

//+------------------------------------------------------------------+
//| Display Chart Info                                               |
//+------------------------------------------------------------------+
void DisplayChartInfo(int rates_total, const double &close[], const datetime &time[])
{
    if(rates_total < 1) return;
    
    int index = 0;
    
    double current_price = close[index];
    double bb_upper = BB_Upper_Buffer[index];
    double bb_lower = BB_Lower_Buffer[index];
    double bb_middle = BB_Middle_Buffer[index];
    double ema9 = EMA9_Buffer[index];
    double ema21 = EMA21_Buffer[index];
    double rsi = RSI_Buffer[index];
    double atr = ATR_Buffer[index];
    
    if(bb_upper <= 0 || bb_lower <= 0 || ema9 <= 0 || rsi < 0 || atr <= 0)
    {
        Comment("Indicator initializing...");
        return;
    }
    
    string signal_text = "";
    if(Signal_Buffer_Arrows[index] > 0)
        signal_text = StringFormat("🟢 BUY SIGNAL (Confirmation: %d/7)", (int)Signal_Confidence[index]);
    else if(Signal_Buffer_Arrows[index] < 0)
        signal_text = StringFormat("🔴 SELL SIGNAL (Confirmation: %d/7)", (int)MathAbs(Signal_Confidence[index]));
    else
        signal_text = "⚪ NO SIGNAL";
    
    string trend = (ema9 > ema21) ? "📈 UPTREND (EMA9 > EMA21)" : "📉 DOWNTREND (EMA9 < EMA21)";
    string rsi_status = "";
    if(rsi > 70)
        rsi_status = "⚠️ OVERBOUGHT (>70)";
    else if(rsi < 30)
        rsi_status = "⚠️ OVERSOLD (<30)";
    else if(rsi > 50)
        rsi_status = "BULLISH (50-70)";
    else
        rsi_status = "BEARISH (30-50)";
    
    double bb_width = bb_upper - bb_lower;
    string volatility = (bb_width > bb_middle * 0.1) ? "HIGH Volatility" : "LOW Volatility";
    
    string comment_text = StringFormat(
        "╔════════════════════════════════════════════╗\n"
        "║   BBMA STRATEGY INDICATOR v3.10 (15M)      ║\n"
        "║   Multi-Confirmation Filter (Noise Filter) ║\n"
        "╚════════════════════════════════════════════╝\n"
        "Time: %s | Symbol: %s\n"
        "═════════════════════════════════════════════\n"
        "💰 Current Price: %.5f\n"
        "═════════════════════════════════════════════\n"
        "%s\n"
        "%s\n"
        "═════════════════════════════════════════════\n"
        "📊 BOLLINGER BANDS:\n"
        "  Upper: %.5f\n"
        "  Middle: %.5f\n"
        "  Lower: %.5f\n"
        "  Width: %.5f (%s)\n"
        "═════════════════════════════════════════════\n"
        "📈 MOVING AVERAGES:\n"
        "  EMA 9: %.5f\n"
        "  EMA 21: %.5f\n"
        "  Difference: %.5f\n"
        "═════════════════════════════════════════════\n"
        "📊 MOMENTUM INDICATORS:\n"
        "  RSI(14): %.2f - %s\n"
        "  ATR(14): %.5f\n"
        "═════════════════════════════════════════════\n"
        "⚙️  SETTINGS:\n"
        "  Signal Strength: %d (1=Aggressive, 3=Conservative)\n"
        "  Min Volume Ratio: %.2f\n"
        "  SL/TP Multiplier: %.1f / %.1f\n"
        "═════════════════════════════════════════════",
        TimeToString(time[0], TIME_DATE|TIME_MINUTES), Symbol(),
        current_price,
        signal_text,
        trend,
        bb_upper, bb_middle, bb_lower, bb_width, volatility,
        ema9, ema21, MathAbs(ema9 - ema21),
        rsi, rsi_status, atr,
        Signal_Strength, Min_Volume_Ratio, SL_Multiplier, TP_Multiplier
    );
    
    Comment(comment_text);
}

//+------------------------------------------------------------------+
//| OnDeinit function                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Comment("");
}

//+------------------------------------------------------------------+
