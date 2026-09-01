//+------------------------------------------------------------------+
//|                          BBMA Strategy Indicator MT5              |
//|                     Optimized for 15M Timeframe                   |
//|              Buy/Sell Signals dengan Filter Noise                 |
//+------------------------------------------------------------------+
#property copyright "Trading Strategy"
#property link      "https://github.com/Ahmad112005"
#property version   "1.00"
#property strict
#property indicator_chart_window

#property indicator_buffers 10
#property indicator_plots 6

// Plotting properties
#property indicator_label1  "BB Upper"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_width1  1

#property indicator_label2  "BB Lower"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_width2  1

#property indicator_label3  "BB Middle"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_width3  1

#property indicator_label4  "EMA 9"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrBlue
#property indicator_width4  2

#property indicator_label5  "EMA 21"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrange
#property indicator_width5  2

#property indicator_label6  "Buy/Sell Signal"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrYellow
#property indicator_width6  3

// Input parameters
input int         BB_Period         = 20;           // Bollinger Bands Period
input double      BB_StdDev         = 2.0;          // Standard Deviation
input int         MA_Period         = 9;            // EMA Period
input int         RSI_Period        = 14;           // RSI Period
input int         MACD_Fast         = 12;           // MACD Fast
input int         MACD_Slow         = 26;           // MACD Slow
input int         MACD_Signal        = 9;           // MACD Signal
input int         ATR_Period        = 14;           // ATR Period
input double      SL_Multiplier     = 1.5;          // Stop Loss Multiplier
input double      TP_Multiplier     = 2.5;          // Take Profit Multiplier
input bool        ShowAlerts        = true;         // Show Alerts

// Indicator buffers
double BB_Upper_Buffer[];
double BB_Lower_Buffer[];
double BB_Middle_Buffer[];
double EMA9_Buffer[];
double EMA21_Buffer[];
double RSI_Buffer[];
double MACD_Buffer[];
double Signal_Buffer[];
double ATR_Buffer[];
double Signal_Buffer_Arrows[];

// Global variables
datetime last_alert_time = 0;
int last_signal = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set buffers as indicator buffers
    SetIndexBuffer(0, BB_Upper_Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, BB_Lower_Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, BB_Middle_Buffer, INDICATOR_DATA);
    SetIndexBuffer(3, EMA9_Buffer, INDICATOR_DATA);
    SetIndexBuffer(4, EMA21_Buffer, INDICATOR_DATA);
    SetIndexBuffer(5, RSI_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(6, MACD_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, Signal_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(8, ATR_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(9, Signal_Buffer_Arrows, INDICATOR_DATA);
    
    // Set short name
    IndicatorSetString(INDICATOR_SHORTNAME, "BBMA Strategy (15M)");
    
    // Set plot line properties
    PlotIndexSetDouble(5, PLOT_ARROW_SHIFT, 10);
    PlotIndexSetInteger(5, PLOT_ARROW, 233); // Arrow UP
    
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
    int start = prev_calculated - 1;
    if(start < 0) start = 0;
    
    // Calculate Bollinger Bands, Moving Averages, RSI, MACD, ATR
    for(int i = start; i < rates_total; i++)
    {
        // Bollinger Bands
        CalculateBollingerBands(i, close, rates_total);
        
        // Moving Averages
        CalculateEMA(i, close, 9, EMA9_Buffer);
        CalculateEMA(i, close, 21, EMA21_Buffer);
        
        // RSI
        CalculateRSI(i, close, rates_total);
        
        // MACD
        CalculateMACD(i, close, rates_total);
        
        // ATR
        CalculateATR(i, high, low, close, rates_total);
        
        // Generate Signals
        if(i > MACD_Slow + MA_Period + BB_Period)
        {
            GenerateSignal(i, close, high, low);
        }
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Bollinger Bands                                        |
//+------------------------------------------------------------------+
void CalculateBollingerBands(int index, const double &close[], int rates_total)
{
    if(index < BB_Period - 1) return;
    
    double sum = 0;
    for(int i = 0; i < BB_Period; i++)
    {
        sum += close[index - i];
    }
    
    double sma = sum / BB_Period;
    BB_Middle_Buffer[index] = sma;
    
    double sum_sq = 0;
    for(int i = 0; i < BB_Period; i++)
    {
        double diff = close[index - i] - sma;
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
                sum += close[index - i];
            ema_buffer[index] = sum / period;
        }
        return;
    }
    
    double multiplier = 2.0 / (period + 1.0);
    ema_buffer[index] = close[index] * multiplier + ema_buffer[index - 1] * (1.0 - multiplier);
}

//+------------------------------------------------------------------+
//| Calculate RSI                                                    |
//+------------------------------------------------------------------+
void CalculateRSI(int index, const double &close[], int rates_total)
{
    if(index < RSI_Period) return;
    
    double gain = 0, loss = 0;
    
    for(int i = 1; i <= RSI_Period; i++)
    {
        double change = close[index - i + 1] - close[index - i];
        if(change > 0)
            gain += change;
        else
            loss += -change;
    }
    
    double avg_gain = gain / RSI_Period;
    double avg_loss = loss / RSI_Period;
    
    double rs = (avg_loss != 0) ? avg_gain / avg_loss : 0;
    RSI_Buffer[index] = 100.0 - (100.0 / (1.0 + rs));
}

//+------------------------------------------------------------------+
//| Calculate MACD                                                   |
//+------------------------------------------------------------------+
void CalculateMACD(int index, const double &close[], int rates_total)
{
    if(index < MACD_Slow) return;
    
    double ema_fast = 0, ema_slow = 0;
    
    // Calculate EMA Fast (12)
    if(index == MACD_Slow - 1)
    {
        double sum = 0;
        for(int i = 0; i < MACD_Fast; i++)
            sum += close[index - i];
        ema_fast = sum / MACD_Fast;
    }
    else if(index > MACD_Slow - 1)
    {
        double multiplier = 2.0 / (MACD_Fast + 1.0);
        ema_fast = close[index] * multiplier + (index > 0 ? MACD_Buffer[index - 1] : close[index]) * (1.0 - multiplier);
    }
    
    // Calculate EMA Slow (26)
    if(index == MACD_Slow - 1)
    {
        double sum = 0;
        for(int i = 0; i < MACD_Slow; i++)
            sum += close[index - i];
        ema_slow = sum / MACD_Slow;
    }
    else if(index > MACD_Slow - 1)
    {
        double multiplier = 2.0 / (MACD_Slow + 1.0);
        ema_slow = close[index] * multiplier + (index > 0 ? (MACD_Buffer[index - 1] - MACD_Buffer[index - 1]) : close[index]) * (1.0 - multiplier);
    }
    
    if(index == MACD_Slow - 1)
        MACD_Buffer[index] = ema_fast - ema_slow;
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                    |
//+------------------------------------------------------------------+
void CalculateATR(int index, const double &high[], const double &low[], const double &close[], int rates_total)
{
    if(index < ATR_Period) return;
    
    double tr = 0;
    double high_low = high[index] - low[index];
    double high_close = MathAbs(high[index] - (index > 0 ? close[index - 1] : close[index]));
    double low_close = MathAbs(low[index] - (index > 0 ? close[index - 1] : close[index]));
    
    tr = MathMax(high_low, MathMax(high_close, low_close));
    
    if(index == ATR_Period - 1)
    {
        double sum = 0;
        for(int i = 0; i < ATR_Period; i++)
        {
            double hl = high[index - i] - low[index - i];
            sum += hl;
        }
        ATR_Buffer[index] = sum / ATR_Period;
    }
    else if(index > ATR_Period - 1)
    {
        ATR_Buffer[index] = (ATR_Buffer[index - 1] * (ATR_Period - 1) + tr) / ATR_Period;
    }
}

//+------------------------------------------------------------------+
//| Generate Buy/Sell Signals                                        |
//+------------------------------------------------------------------+
void GenerateSignal(int index, const double &close[], const double &high[], const double &low[])
{
    Signal_Buffer_Arrows[index] = 0;
    
    if(index < 1) return;
    
    double current_price = close[index];
    double prev_price = close[index - 1];
    
    double bb_upper = BB_Upper_Buffer[index];
    double bb_lower = BB_Lower_Buffer[index];
    double bb_middle = BB_Middle_Buffer[index];
    
    double ema9 = EMA9_Buffer[index];
    double ema21 = EMA21_Buffer[index];
    
    double rsi = RSI_Buffer[index];
    double prev_rsi = (index > 0) ? RSI_Buffer[index - 1] : rsi;
    
    double macd_current = MACD_Buffer[index];
    double macd_prev = (index > 0) ? MACD_Buffer[index - 1] : macd_current;
    
    double atr = ATR_Buffer[index];
    
    // ==================== BUY SIGNAL ====================
    bool buy_signal = false;
    string buy_reason = "";
    
    // Strong BUY: Price touch BB Lower + EMA 9 above EMA 21
    if(current_price <= bb_lower * 1.01 && prev_price > bb_lower && ema9 > ema21 && rsi < 40)
    {
        buy_signal = true;
        buy_reason = "STRONG BUY: Price at BB Lower + EMA Bullish";
    }
    
    // Medium BUY: MACD crossover + Price above EMA9
    else if(macd_prev < 0 && macd_current > 0 && current_price > ema9 && rsi < 60 && rsi > 25)
    {
        buy_signal = true;
        buy_reason = "BUY: MACD Bullish Crossover";
    }
    
    // ==================== SELL SIGNAL ====================
    bool sell_signal = false;
    string sell_reason = "";
    
    // Strong SELL: Price touch BB Upper + EMA 9 below EMA 21
    if(current_price >= bb_upper * 0.99 && prev_price < bb_upper && ema9 < ema21 && rsi > 60)
    {
        sell_signal = true;
        sell_reason = "STRONG SELL: Price at BB Upper + EMA Bearish";
    }
    
    // Medium SELL: MACD crossover below + Price below EMA9
    else if(macd_prev > 0 && macd_current < 0 && current_price < ema9 && rsi > 40 && rsi < 75)
    {
        sell_signal = true;
        sell_reason = "SELL: MACD Bearish Crossover";
    }
    
    // Plot signals
    if(buy_signal)
    {
        Signal_Buffer_Arrows[index] = current_price;
        last_signal = 1;
        
        if(ShowAlerts && time[index] != last_alert_time)
        {
            double stop_loss = current_price - (atr * SL_Multiplier);
            double take_profit = current_price + (atr * TP_Multiplier);
            
            string alert_msg = StringFormat(
                "🟢 BUY SIGNAL on %s\nPrice: %.5f\nStop Loss: %.5f\nTake Profit: %.5f\nReason: %s",
                Symbol(), current_price, stop_loss, take_profit, buy_reason
            );
            
            Alert(alert_msg);
            last_alert_time = time[index];
        }
    }
    else if(sell_signal)
    {
        Signal_Buffer_Arrows[index] = current_price;
        last_signal = -1;
        
        if(ShowAlerts && time[index] != last_alert_time)
        {
            double stop_loss = current_price + (atr * SL_Multiplier);
            double take_profit = current_price - (atr * TP_Multiplier);
            
            string alert_msg = StringFormat(
                "🔴 SELL SIGNAL on %s\nPrice: %.5f\nStop Loss: %.5f\nTake Profit: %.5f\nReason: %s",
                Symbol(), current_price, stop_loss, take_profit, sell_reason
            );
            
            Alert(alert_msg);
            last_alert_time = time[index];
        }
    }
}

//+------------------------------------------------------------------+
//| OnDeinit function                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Cleanup
    Comment("");
}

//+------------------------------------------------------------------+
