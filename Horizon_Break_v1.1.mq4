/*      .=====================================.
       /             Horizon Break             \
      |               by Edorenta               |
       \           Range Breakout Bot          /
        '====================================='
*/

#property copyright     "Paul de Renty (Edorenta @ ForexFactory.com)"
#property link          "edorenta@gmail.com (mp me on FF rather than by email)"
#property description   "Horizon Break : Horizontal Key Level Experiment"
#property version       "1.1"
string version =        "1.1";
#property strict
#include <stdlib.mqh>

enum hi {HH  //Highest High
        ,HL  //Highest Low
        ,HC  //Highest Close
        ,HO  //Highest Open
};

enum lo {LH  //Lowest High
        ,LL  //Lowest Low
        ,LC  //Lowest Close
        ,LO  //Lowest Open
};

extern hi hi_mode = HH;                      //High Mode
extern lo lo_mode = LL;                      //Low Mode

extern int hilo_tf = 40;                    //High / Low Horizon
extern int hilo_tf_shift = 20;              //Old Channel Shift

enum rk     {fixed_lot      //Static Lotsize
            ,dyna_lot       //Dynamic Lotsize
            ,fixed_money    //Static $$
            ,dyna_money     //Dynamic $$
};

enum mm     {classic        //Classic
            ,mart           //Martingale
            ,r_mart         //Anti-Martingale
            ,scale          //Scale-in Loss
            ,r_scale        //Scale-in Profit
};

extern rk risk_mode = dyna_money; //Lotsize Calculation Mode

extern double b_lots = 0.01; //Base Lots       [Static Lots]
extern double b_lots_risk = 0.5; //Base Risk Lots  [Dynamic Lots %K]
extern double b_money = 0.01; //Base Money      [Static Money $$]
extern double b_money_risk = 0.01; //Base Risk Money [Dynamic Money %K $$]

extern mm mm_mode = scale; //Money Management Mode (Classic if > 1 trade)
extern double xtor = 1.5; //Martingale Multiplicator
extern double increment = 0.01; //Scaler Increment

extern int atr_p = 30; //ATR SL period
extern double atr_x = 3; //ATR SL multiplier
extern double RR = 1.1; //Risk Reward Target (SL multiplier)
extern double offset = 10; //Channel Order Offset (% of Reward)
extern bool enable_trail = false; //Enable Trailing Stops
extern double trail_x = 15; //Trailing (% of Reward)
extern int expiration_mins = 720; //Exp. Mins for Pending Orders
extern bool rev_signal = false; //Reverse Signal (mean reversion)
int max_longs = 1; //Max Long Trades
int max_shorts = 1; //Max Short Trades

extern int max_risk_trades = 6; //Max Recovery Trades
extern double emergency_stop_pc = 20; //EA DD Hard Stop (%K)
extern double daily_profit_pc = 3; //Stop After Daily Profit (%K)
extern double daily_loss_pc = 3; //Stop After Daily Loss (%K)
extern int magic = 123; //Magic Number
extern int slippage = 15; //Slippage
long chart_ID = 0;

string hi_name = "Channel Top"; //Channel Top Name
string lo_name = "Channel Bot"; //Channel Bot Name
string phi_name = "Channel Old Top"; //Channel Old Top Name
string plo_name = "Channel Old Bot"; //Channel Old Bot Name
string mid_name = "Pivot"; //Channel Pivot Name

extern color hi_clr = Turquoise; //Channel Top Color
extern color lo_clr = Magenta; //Channel Bot Color
extern color phi_clr = DarkGray; //Channel Old Top Color
extern color plo_clr = DarkGray; //Channel Old Bot Color
extern color mid_clr = DarkOrange; //Channel Pivot Color

extern ENUM_LINE_STYLE style = STYLE_SOLID; //Channel Style
extern int width = 1; //Channel Levels width
bool back = true; //Levels in the Background
bool selection = true; //Levels Selectable
bool hidden = true; //Hidden in the Object list

extern bool show_gui = true; //Show The EA GUI

extern color color1 = LightGray; //EA's name color
extern color color2 = DarkOrange; //EA's balance & info color
extern color color3 = Turquoise; //EA's profit color
extern color color4 = Magenta; //EA's loss color

int hi_shift, lo_shift, phi_shift, plo_shift, mid_shift;
double hi_px, lo_px, mid_px, phi_px, plo_px;

int current_bar = 0; //Bars counter for 1 move per bar
bool in_long = false, in_short = false;

//Data count variables initialization

double max_acc_dd = 0;
double max_acc_dd_pc = 0;
double max_dd = 0;
double max_dd_pc = 0;
double max_acc_runup = 0;
double max_acc_runup_pc = 0;
double max_runup = 0;
double max_runup_pc = 0;
int max_chain_win = 0;
int max_chain_loss = 0;
int max_spread = 0;

/*       ____________________________________________
         T                                          T
         T                 ON TICK                  T
         T__________________________________________T
*/

int init() {
    if (show_gui) {
        HUD();
    }
    return (0);
}

/*       ____________________________________________
         T                                          T
         T                 ON TICK                  T
         T__________________________________________T
*/

int deinit() {
    return (0);
}

/*       ____________________________________________
         T                                          T
         T                 ON TICK                  T
         T__________________________________________T
*/

void OnTick() {

    EA_name();
    if (show_gui == true) {
        GUI();
    }

    //Long trade setup : draw top and previous top, if same then buystop

    if (current_bar != Bars) {

        switch (hi_mode) {
        case HH:
            hi_shift = iHighest(Symbol(), 0, MODE_HIGH, hilo_tf, 0);
            phi_shift = iHighest(Symbol(), 0, MODE_HIGH, hilo_tf, hilo_tf_shift);
            break;
        case HL:
            hi_shift = iHighest(Symbol(), 0, MODE_LOW, hilo_tf, 0);
            phi_shift = iHighest(Symbol(), 0, MODE_LOW, hilo_tf, hilo_tf_shift);
            break;
        case HC:
            hi_shift = iHighest(Symbol(), 0, MODE_CLOSE, hilo_tf, 0);
            phi_shift = iHighest(Symbol(), 0, MODE_CLOSE, hilo_tf, hilo_tf_shift);
            break;
        case HO:
            hi_shift = iHighest(Symbol(), 0, MODE_OPEN, hilo_tf, 0);
            phi_shift = iHighest(Symbol(), 0, MODE_OPEN, hilo_tf, hilo_tf_shift);
            break;
        }
        switch (lo_mode) {
        case LH:
            lo_shift = iLowest(Symbol(), 0, MODE_HIGH, hilo_tf, 0);
            plo_shift = iLowest(Symbol(), 0, MODE_HIGH, hilo_tf, hilo_tf_shift);
            break;
        case LL:
            lo_shift = iLowest(Symbol(), 0, MODE_LOW, hilo_tf, 0);
            plo_shift = iLowest(Symbol(), 0, MODE_LOW, hilo_tf, hilo_tf_shift);
            break;
        case LC:
            lo_shift = iLowest(Symbol(), 0, MODE_CLOSE, hilo_tf, 0);
            plo_shift = iLowest(Symbol(), 0, MODE_CLOSE, hilo_tf, hilo_tf_shift);
            break;
        case LO:
            lo_shift = iLowest(Symbol(), 0, MODE_OPEN, hilo_tf, 0);
            plo_shift = iLowest(Symbol(), 0, MODE_OPEN, hilo_tf, hilo_tf_shift);
            break;
        }

        if (hi_px != iHigh(Symbol(), 0, hi_shift)) {
            hi_px = iHigh(Symbol(), 0, hi_shift);
            mid_px = NormalizeDouble((hi_px + lo_px) / 2, Digits);
            draw_top();
            draw_mid();
        }

        if (phi_px != iHigh(Symbol(), 0, phi_shift)) {
            phi_px = iHigh(Symbol(), 0, phi_shift);
            draw_ptop();
        }

        if (in_long == false) {
            if (hi_shift == phi_shift) {
                refresh_long_book(hi_px);
                in_long = true;
            }
        }

        if (hi_shift != phi_shift) {
            in_long = false;
        }

        //Short trade setup : draw bot and previous bot, if same then sellstop

        if (lo_px != iLow(Symbol(), 0, lo_shift)) {
            lo_px = iLow(Symbol(), 0, lo_shift);
            mid_px = NormalizeDouble((hi_px + lo_px) / 2, Digits);
            draw_bot();
            draw_mid();
        }

        if (plo_px != iLow(Symbol(), 0, plo_shift)) {
            plo_px = iLow(Symbol(), 0, plo_shift);
            draw_pbot();
        }

        if (in_short == false) {
            if (lo_shift == plo_shift) {
                refresh_short_book(lo_px);
                in_short = true;
            }
        }

        if (lo_shift != plo_shift) {
            in_short = false;
        }

        //Trail if necessary

        if (enable_trail == true) {
            trail();
        }

        current_bar = Bars; //Don't calculate again this bar
    }

    string comment = "High: " + (string) hi_px + " || Low: " + (string) lo_px + " || Pivot: " + (string) mid_px + " || SL: " + SL() + " (" + DoubleToStr(SL() / (10 * Point), 1) + " pips)";
    Comment(comment);

}

/*       ____________________________________________
         T                                          T
         T   ORDER MANAGEMENT & TRADING FUNCTIONS   T
         T__________________________________________T
*/

void trail() {
    double TS = NormalizeDouble(TP() * (trail_x / 100), Digits);
    //   Comment("Trailing Stop :"+TS);
    if (TS != 0) {
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                if (OrderType() == OP_BUY) {
                    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                    if (Bid - OrderOpenPrice() > TS && (OrderStopLoss() < Bid - TS || (OrderStopLoss() == 0))) {
                        OrderModify(OrderTicket(), OrderOpenPrice(), Bid - TS, OrderTakeProfit(), 0, Turquoise);
                    }
                }
                if (OrderType() == OP_SELL) {
                    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                    if (OrderOpenPrice() - Ask > TS && (OrderStopLoss() > Ask + TS || (OrderStopLoss() == 0))) {
                        OrderModify(OrderTicket(), OrderOpenPrice(), Ask + TS, OrderTakeProfit(), 0, Magenta);
                    }
                }
            }
        }
    }
}

void refresh_long_book(double price) {

    if (rev_signal == false) {
        if (trade_counter(1) == 0) {
            order_long(price);
        }
        if (trade_counter(1) > 0) {
            for (int i = 0; i < OrdersTotal(); i++) {
                if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_BUYSTOP) {
                    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                    if (OrderOpenPrice() != price) {
                        cancel_long();
                        order_long(price);
                    }
                }
            }
        }
    }

    if (rev_signal == true) {
        if (trade_counter(4) == 0) {
            order_long(price);
        }
        if (trade_counter(4) > 0) {
            for (int i = 0; i < OrdersTotal(); i++) {
                if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_SELLLIMIT) {
                    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                    if (OrderOpenPrice() != price) {
                        cancel_long();
                        order_long(price);
                    }
                }
            }
        }
    }
}

void refresh_short_book(double price) {

    if (rev_signal == false) {
        if (trade_counter(2) == 0) {
            order_short(price);
        }
        if (trade_counter(2) > 0) {
            for (int i = 0; i < OrdersTotal(); i++) {
                if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_SELLSTOP) {
                    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                    if (OrderOpenPrice() != price) {
                        cancel_short();
                        order_short(price);
                    }
                }
            }
        }
    }

    if (rev_signal == true) {
        if (trade_counter(3) == 0) {
            order_short(price);
        }
        if (trade_counter(3) > 0) {
            for (int i = 0; i < OrdersTotal(); i++) {
                if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_BUYLIMIT) {
                    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                    if (OrderOpenPrice() != price) {
                        cancel_short();
                        order_short(price);
                    }
                }
            }
        }
    }
}

void cancel_long() {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if ((OrderMagicNumber() == magic) && OrderSymbol() == Symbol()) {
            if (rev_signal == false && OrderType() == OP_BUYSTOP) {
                OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                OrderDelete(OrderTicket());
            }
            if (rev_signal == true && OrderType() == OP_SELLLIMIT) {
                OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                OrderDelete(OrderTicket());
            }
        }
    }
}

void cancel_short() {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if ((OrderMagicNumber() == magic) && OrderSymbol() == Symbol()) {
            if (rev_signal == false && OrderType() == OP_SELLSTOP) {
                OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                OrderDelete(OrderTicket());
            }
            if (rev_signal == true && OrderType() == OP_BUYLIMIT) {
                OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
                OrderDelete(OrderTicket());
            }
        }
    }
}

void close_all() {

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic) {
            if (OrderType() == OP_BUY) {
                OrderClose(OrderTicket(), OrderLots(), Bid, slippage, Turquoise);
            }
            if (OrderType() == OP_SELL) {
                OrderClose(OrderTicket(), OrderLots(), Ask, slippage, Magenta);
            }
        }
    }
}

void order_long(double price) {
    price = NormalizeDouble(price + (offset / 100) * SL(), Digits);
    double lots = b_lots;
    int nb_longs = trade_counter(5);
    int nb_shorts = trade_counter(6);

    int expiration = TimeCurrent() + (PERIOD_M1 * 60) * expiration_mins;
    if (expiration < 600) expiration = 600;
    if (trade_counter(1) == 0 && nb_longs < max_longs && rev_signal == false) {
        int ticket = OrderSend(Symbol(), OP_BUYSTOP, lotsize(), price, slippage, price - SL(), price + TP(), "", magic, expiration);
        if (ticket < 0) {
            //         Comment("OrderSend Error: " ,ErrorDescription(GetLastError()));
        } else {
            //         Comment("Order Sent Successfully, Ticket # is: " + string(ticket));  
        }
    }
    if (trade_counter(4) == 0 && nb_shorts < max_shorts && rev_signal == true) {
        int ticket = OrderSend(Symbol(), OP_SELLLIMIT, lotsize(), price, slippage, price + SL(), price - TP(), "", magic, expiration);
        if (ticket < 0) {
            //         Comment("OrderSend Error: " ,ErrorDescription(GetLastError()));
        } else {
            //         Comment("Order Sent Successfully, Ticket # is: " + string(ticket));  
        }
    }
}

void order_short(double price) {
    price = NormalizeDouble(price - (offset / 100) * SL(), Digits);
    double lots = b_lots;
    int nb_longs = trade_counter(5);
    int nb_shorts = trade_counter(6);

    int expiration = TimeCurrent() + (PERIOD_M1 * 60) * expiration_mins;
    if (expiration < 600) expiration = 600;
    if (trade_counter(2) == 0 && nb_shorts < max_shorts && rev_signal == false) {
        int ticket = OrderSend(Symbol(), OP_SELLSTOP, lotsize(), price, slippage, price + SL(), price - TP(), "", magic, expiration);
        if (ticket < 0) {
            Comment("OrderSend Error: ", ErrorDescription(GetLastError()));
        } else {
            Comment("Order Sent Successfully, Ticket # is: " + string(ticket));
        }
    }
    if (trade_counter(3) == 0 && nb_longs < max_longs && rev_signal == true) {
        int ticket = OrderSend(Symbol(), OP_BUYLIMIT, lotsize(), price, slippage, price - SL(), price + TP(), "", magic, expiration);
        if (ticket < 0) {
            Comment("OrderSend Error: ", ErrorDescription(GetLastError()));
        } else {
            Comment("Order Sent Successfully, Ticket # is: " + string(ticket));
        }
    }
}

double TP() {

    double stop_lvl = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
    double atr1 = iATR(NULL, 0, atr_p, 0);
    double atr2 = iATR(NULL, 0, 2 * atr_p, 0);
    double atr3 = NormalizeDouble(((atr1 + atr2) / 2) * atr_x, Digits);
    double ma1 = iMA(NULL, 0, atr_p * 2, 0, MODE_LWMA, PRICE_HIGH, 0);
    double ma2 = iMA(NULL, 0, atr_p * 2, 0, MODE_LWMA, PRICE_LOW, 0);
    double ma3 = NormalizeDouble(atr_x * (ma1 - ma2), Digits);
    double tp = NormalizeDouble(RR * ((atr3 + (ma3 / 1.25)) / 2) * atr_x, Digits);

    if (stop_lvl > tp) tp = stop_lvl;

    return (tp);
}

double SL() {

    double stop_lvl = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
    double atr1 = iATR(NULL, 0, atr_p, 0);
    double atr2 = iATR(NULL, 0, 2 * atr_p, 0);
    double atr3 = NormalizeDouble(((atr1 + atr2) / 2) * atr_x, Digits);
    double ma1 = iMA(NULL, 0, atr_p * 2, 0, MODE_LWMA, PRICE_HIGH, 0);
    double ma2 = iMA(NULL, 0, atr_p * 2, 0, MODE_LWMA, PRICE_LOW, 0);
    double ma3 = NormalizeDouble(atr_x * (ma1 - ma2), Digits);
    double sl = NormalizeDouble(((atr3 + (ma3 / 1.25)) / 2) * atr_x, Digits);

    if (stop_lvl > sl) sl = stop_lvl;

    return (sl);
}

/*       ____________________________________________
         T                                          T
         T               DATA FUNCTIONS             T
         T__________________________________________T
*/

double lotsize() {
    int chain_loss = data_counter(5);
    int chain_win = data_counter(6);
    double temp_lots, risk_to_SL, mlots = 0;
    double equity = AccountEquity();
    double margin = AccountFreeMargin();
    double maxlot = MarketInfo(Symbol(), MODE_MAXLOT);
    double minlot = MarketInfo(Symbol(), MODE_MINLOT);
    double pip_value = MarketInfo(Symbol(), MODE_TICKVALUE);
    double pip_size = MarketInfo(Symbol(), MODE_TICKSIZE);
    int leverage = AccountLeverage();

    risk_to_SL = SL() * (pip_value / pip_size);

    switch (risk_mode) {
    case fixed_lot:
        temp_lots = b_lots;
        break;
    case fixed_money:
        if (SL() != 0) {
            temp_lots = NormalizeDouble(b_money / (risk_to_SL), 2);
        }
        break;
    case dyna_lot:
        temp_lots = NormalizeDouble(((equity * leverage) * b_lots_risk) / 100000, 2);
        break;
    case dyna_money:
        if (SL() != 0) {
            temp_lots = NormalizeDouble((b_money_risk * equity) / (risk_to_SL * 1000), 2);
        }
        break;
    }

    if (b_lots < minlot) b_lots = minlot;
    if (b_lots > maxlot) b_lots = maxlot;

    switch (mm_mode) {
    case mart:
        if (OrdersHistoryTotal() != 0) mlots = NormalizeDouble(temp_lots * (MathPow(xtor, (chain_loss + 1))), 2);
        break;
    case r_mart:
        if (OrdersHistoryTotal() != 0) mlots = NormalizeDouble(temp_lots * (MathPow(xtor, (chain_win + 1))), 2);
        break;
    case scale:
        if (OrdersHistoryTotal() != 0) mlots = temp_lots + (increment * chain_loss);
        break;
    case r_scale:
        if (OrdersHistoryTotal() != 0) mlots = temp_lots + (increment * chain_win);
        break;
    case classic:
        break;
    }

    if (mlots < minlot) mlots = minlot;
    if (mlots > maxlot) mlots = maxlot;

    return (mlots);
}

int trade_counter(int type_switch) {

    int nb_longs = 0, nb_shorts = 0, nb_buystops = 0, nb_buylimits = 0, nb_sellstops = 0, nb_selllimits = 0, count;

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic) {
                if (OrderType() == OP_BUYSTOP) {
                    nb_buystops++;
                }
                if (OrderType() == OP_SELLSTOP) {
                    nb_sellstops++;
                }
                if (OrderType() == OP_BUYLIMIT) {
                    nb_buylimits++;
                }
                if (OrderType() == OP_SELLLIMIT) {
                    nb_selllimits++;
                }
                if (OrderType() == OP_BUY) {
                    nb_longs++;
                }
                if (OrderType() == OP_SELL) {
                    nb_shorts++;
                }
            }
        }
    }
    switch (type_switch) {
    case 1:
        count = nb_buystops;
        break;
    case 2:
        count = nb_sellstops;
        break;
    case 3:
        count = nb_buylimits;
        break;
    case 4:
        count = nb_selllimits;
        break;
    case 5:
        count = nb_longs;
        break;
    case 6:
        count = nb_shorts;
        break;
    }
    return (count);
}

double data_counter(int key) {

    double count_tot = 0, balance = AccountBalance(), equity = AccountEquity();
    double drawdown = 0, runup = 0, lots = 0, profit = 0;

    switch (key) {

    case (1): //All time wins counter
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                count_tot++;
            }
        }
        break;

    case (2): //All time loss counter
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                count_tot++;
            }
        }
        break;

    case (3): //All time profit
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
            count_tot = profit;
        }
        break;

    case (4): //All time lots
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                lots = lots + OrderLots();
            }
            count_tot = lots;
        }
        break;

    case (5): //Chain Loss
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                count_tot++;
            }
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                count_tot = 0;
            }
        }
        break;

    case (6): //Chain Win
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                count_tot++;
            }
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                count_tot = 0;
            }
        }
        break;

    case (7): //Chart Drawdown % (if equity < balance)
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit > 0) drawdown = 0;
        else drawdown = NormalizeDouble((profit / balance) * 100, 2);
        count_tot = drawdown;
        break;

    case (8): //Acc Drawdown % (if equity < balance)
        if (equity >= balance) drawdown = 0;
        else drawdown = NormalizeDouble(((equity - balance) * 100) / balance, 2);
        count_tot = drawdown;
        break;

    case (9): //Chart dd money (if equity < balance)
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit >= 0) drawdown = 0;
        else drawdown = profit;
        count_tot = drawdown;
        break;

    case (10): //Acc dd money (if equiy < balance)
        if (equity >= balance) drawdown = 0;
        else drawdown = equity - balance;
        count_tot = drawdown;
        break;

    case (11): //Chart Runup %
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit < 0) runup = 0;
        else runup = NormalizeDouble((profit / balance) * 100, 2);
        count_tot = runup;
        break;

    case (12): //Acc Runup %
        if (equity < balance) runup = 0;
        else runup = NormalizeDouble(((equity - balance) * 100) / balance, 2);
        count_tot = runup;
        break;

    case (13): //Chart runup money
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit < 0) runup = 0;
        else runup = profit;
        count_tot = runup;
        break;

    case (14): //Acc runup money
        if (equity < balance) runup = 0;
        else runup = equity - balance;
        count_tot = runup;
        break;

    case (15): //Current profit here
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        count_tot = profit;
        break;

    case (16): //Current profit acc
        count_tot = AccountProfit();
        break;

    case (17): //Gross profits
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        count_tot = profit;
        break;

    case (18): //Gross loss
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        count_tot = profit;
        break;

    case (19): //Weird Sum 4 Target calculation
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                count_tot = OrderLots() * (OrderCommission() + OrderOpenPrice());
            }
        }

    case (20): //Current lots long
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_BUY) {
                count_tot = count_tot + OrderLots();
            }
        }

    case (21): //Current lots short
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_SELL) {
                count_tot = count_tot + OrderLots();
            }
        }
        break;
    }
    return (count_tot);
}

double Earnings(int shift) {
    double aggregated_profit = 0;
    for (int position = 0; position < OrdersHistoryTotal(); position++) {
        if (!(OrderSelect(position, SELECT_BY_POS, MODE_HISTORY))) break;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic)
            if (OrderCloseTime() >= iTime(Symbol(), PERIOD_D1, shift) && OrderCloseTime() < iTime(Symbol(), PERIOD_D1, shift) + 86400) aggregated_profit = aggregated_profit + OrderProfit() + OrderCommission() + OrderSwap();
    }
    return (aggregated_profit);
}

/*       ____________________________________________
         T                                          T
         T             VISUAL FUNCTIONS             T
         T__________________________________________T
*/

/*       ____________________________________________
         T                                          T
         T       DRAWING THE LINES FUNCTIONS        T
         T__________________________________________T
*/

bool draw_line(color clr, double px, string name) {

    ObjectDelete(chart_ID, name);
    ObjectCreate(chart_ID, name, OBJ_HLINE, 0, Time[0], px);
    ObjectSet(name, OBJPROP_COLOR, clr);
    ObjectSet(name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
    ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
    ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
    WindowRedraw();

    return (true);
}

bool erase_line(string name) {
    ResetLastError();
    ObjectDelete(chart_ID, name);
    if (!ObjectDelete(chart_ID, name)) {
        Print(__FUNCTION__, ": failed to delete the honrizontal line " + name + "; Error code = ", GetLastError());
        return (false);
    }
    return (true);
}

void draw_top() {
    draw_line(hi_clr, hi_px, hi_name);
}

void draw_bot() {
    draw_line(lo_clr, lo_px, lo_name);
}

void draw_ptop() {
    draw_line(phi_clr, phi_px, phi_name);
}

void draw_pbot() {
    draw_line(plo_clr, plo_px, plo_name);
}

void draw_mid() {
    draw_line(mid_clr, mid_px, mid_name);
}

void erase_top() {
    erase_line(hi_name);
}

void erase_bot() {
    erase_line(lo_name);
}

void erase_ptop() {
    erase_line(phi_name);
}

void erase_pbot() {
    erase_line(plo_name);
}

void erase_mid() {
    erase_line(mid_name);
}

/*       ____________________________________________
         T                                          T
         T                DESIGN GUI                T
         T__________________________________________T
*/

//--- HUD Rectangle
void HUD() {
    ObjectCreate(ChartID(), "HUD", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    //--- set label coordinates
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_XDISTANCE, 0);
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_YDISTANCE, 28);
    //--- set label size
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_XSIZE, 280);
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_YSIZE, 600);
    //--- set background color
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_BGCOLOR, clrBlack);
    //--- set border type
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    //--- set the chart's corner, relative to which point coordinates are defined
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_CORNER, 4);
    //--- set flat border color (in Flat mode)
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_COLOR, clrWhite);
    //--- set flat border line style
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_STYLE, STYLE_SOLID);
    //--- set flat border width
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_WIDTH, 1);
    //--- display in the foreground (false) or background (true)
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_BACK, false);
    //--- enable (true) or disable (false) the mode of moving the label by mouse
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_SELECTABLE, false);
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_SELECTED, false);
    //--- hide (true) or display (false) graphical object name in the object list
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_HIDDEN, true);
    //--- set the priority for receiving the event of a mouse click in the chart
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_ZORDER, 0);
}

void GUI() {

    int total_wins = data_counter(1);
    int total_loss = data_counter(2);
    int total_trades = total_wins + total_loss;
    int total_opened_trades = trade_counter(5) + trade_counter(6);

    double total_profit = data_counter(3);
    double total_volumes = data_counter(4);
    int chain_loss = data_counter(5);
    int chain_win = data_counter(6);

    double chart_dd_pc = data_counter(7);
    double acc_dd_pc = data_counter(8);
    double chart_dd = data_counter(9);
    double acc_dd = data_counter(10);

    double chart_runup_pc = data_counter(11);
    double acc_runup_pc = data_counter(12);
    double chart_runup = data_counter(13);
    double acc_runup = data_counter(14);

    double chart_profit = data_counter(15);
    double acc_profit = data_counter(16);

    double gross_profits = data_counter(17);
    double gross_loss = data_counter(18);

    //pnl vs profit factor
    double profit_factor;
    if (gross_loss != 0 && gross_profits != 0) profit_factor = NormalizeDouble(gross_profits / MathAbs(gross_loss), 2);

    //Total volumes vs Average
    double av_volumes;
    if (total_volumes != 0 && total_trades != 0) av_volumes = NormalizeDouble(total_volumes / total_trades, 2);

    //Total trades vs winrate
    int winrate;
    if (total_trades != 0) winrate = (total_wins * 100 / total_trades);

    //Relative DD vs Max DD %
    if (chart_dd_pc < max_dd_pc) max_dd_pc = chart_dd_pc;
    if (acc_dd_pc < max_acc_dd_pc) max_acc_dd_pc = acc_dd_pc;
    //Relative DD vs Max DD $$
    if (chart_dd < max_dd) max_dd = chart_dd;
    if (acc_dd < max_acc_dd) max_acc_dd = acc_dd;

    //Relative runup vs Max runup %
    if (chart_runup_pc > max_runup_pc) max_runup_pc = chart_runup_pc;
    if (acc_runup_pc > max_acc_runup_pc) max_acc_runup_pc = acc_runup_pc;
    //Relative runup vs Max runup $$
    if (chart_runup > max_runup) max_runup = chart_runup;
    if (acc_runup > max_acc_runup) max_acc_runup = acc_runup;

    //Spread vs Maxspread
    if (MarketInfo(Symbol(), MODE_SPREAD) > max_spread) max_spread = MarketInfo(Symbol(), MODE_SPREAD);

    //Chains vs Max chains
    if (chain_loss > max_chain_loss) max_chain_loss = chain_loss;
    if (chain_win > max_chain_win) max_chain_win = chain_win;

    //--- Currency crypt

    string curr = "none";

    if (AccountCurrency() == "USD") curr = "$";
    if (AccountCurrency() == "JPY") curr = "¥";
    if (AccountCurrency() == "EUR") curr = "€";
    if (AccountCurrency() == "GBP") curr = "£";
    if (AccountCurrency() == "CHF") curr = "CHF";
    if (AccountCurrency() == "AUD") curr = "A$";
    if (AccountCurrency() == "CAD") curr = "C$";
    if (AccountCurrency() == "RUB") curr = "руб";

    if (curr == "none") curr = AccountCurrency();

    //--- Equity / balance / floating

    string txt1, content;
    int content_len = StringLen(content);

    txt1 = version + "50";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 75);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "51";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 94);
    }
    ObjectSetText(txt1, "Portfolio", 12, "Century Gothic", color1);

    txt1 = version + "52";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 99);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "100";
    if (AccountEquity() >= AccountBalance()) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 117);
        }

        if (chart_profit == 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 16, "Century Gothic", color3);
        if (chart_profit != 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 11, "Century Gothic", color3);
    }
    if (AccountEquity() < AccountBalance()) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 117);
        }
        if (chart_profit == 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 16, "Century Gothic", color4);
        if (chart_profit != 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 11, "Century Gothic", color4);
    }

    txt1 = version + "101";
    if (chart_profit > 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 135);
        }
        ObjectSetText(txt1, "Floating chart P&L : +" + DoubleToStr(chart_profit, 2) + curr, 9, "Century Gothic", color3);
    }
    if (chart_profit < 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 135);
        }
        ObjectSetText(txt1, "Floating chart P&L : " + DoubleToStr(chart_profit, 2) + curr, 9, "Century Gothic", color4);
    }
    if (total_opened_trades == 0) ObjectDelete(txt1);

    txt1 = version + "102";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        if (total_opened_trades == 0) ObjectSet(txt1, OBJPROP_YDISTANCE, 152);
        if (total_opened_trades != 0) ObjectSet(txt1, OBJPROP_YDISTANCE, 152);
    }
    if (total_opened_trades == 0) ObjectSetText(txt1, "Balance : " + DoubleToStr(AccountBalance(), 2) + curr, 9, "Century Gothic", color2);
    if (total_opened_trades != 0) ObjectSetText(txt1, "Balance : " + DoubleToStr(AccountBalance(), 2) + curr, 9, "Century Gothic", color2);

    //--- Analytics

    txt1 = version + "53";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 156);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "54";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 175);
    }
    ObjectSetText(txt1, "Analytics", 12, "Century Gothic", color1);

    txt1 = version + "55";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 180);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "200";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 200);
    }
    if (chart_runup >= 0) {
        ObjectSetText(txt1, "Chart runup : " + DoubleToString(chart_runup_pc, 2) + "% [" + DoubleToString(chart_runup, 2) + curr + "]", 8, "Century Gothic", color3);
    }
    if (chart_dd < 0) {
        ObjectSetText(txt1, "Chart drawdown : " + DoubleToString(chart_dd_pc, 2) + "% [" + DoubleToString(chart_dd, 2) + curr + "]", 8, "Century Gothic", color4);
    }

    txt1 = version + "201";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 212);
    }
    if (acc_runup >= 0) {
        ObjectSetText(txt1, "Acc runup : " + DoubleToString(acc_runup_pc, 2) + "% [" + DoubleToString(acc_runup, 2) + curr + "]", 8, "Century Gothic", color3);
    }
    if (acc_dd < 0) {
        ObjectSetText(txt1, "Acc DD : " + DoubleToString(acc_dd_pc, 2) + "% [" + DoubleToString(acc_dd, 2) + curr + "]", 8, "Century Gothic", color4);
    }

    txt1 = version + "202";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 224);
    }
    ObjectSetText(txt1, "Max chart runup : " + DoubleToString(max_runup_pc, 2) + "% [" + DoubleToString(max_runup, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "203";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 236);
    }
    ObjectSetText(txt1, "Max chart drawdon : " + DoubleToString(max_dd_pc, 2) + "% [" + DoubleToString(max_dd, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "204";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 248);
    }
    ObjectSetText(txt1, "Max acc runup : " + DoubleToString(max_acc_runup_pc, 2) + "% [" + DoubleToString(max_acc_runup, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "205";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 260);
    }
    ObjectSetText(txt1, "Max acc drawdown : " + DoubleToString(max_acc_dd_pc, 2) + "% [" + DoubleToString(max_acc_dd, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "206";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 271);
    }
    ObjectSetText(txt1, "Trades won : " + IntegerToString(total_wins, 0) + " II Trades lost : " + IntegerToString(total_loss, 0) + " [" + DoubleToString(winrate, 0) + "% winrate]", 8, "Century Gothic", color2);

    txt1 = version + "207";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 284);
    }
    ObjectSetText(txt1, "W-Chain : " + IntegerToString(chain_win, 0) + " [Max : " + IntegerToString(max_chain_win, 0) + "] II L-Chain : " + IntegerToString(chain_loss, 0) + " [Max : " + IntegerToString(max_chain_loss, 0) + "]", 8, "Century Gothic", color2);

    txt1 = version + "208";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 296);
    }
    ObjectSetText(txt1, "Overall volume traded : " + DoubleToString(total_volumes, 2) + " lots", 8, "Century Gothic", color2);

    txt1 = version + "209";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 308);
    }
    ObjectSetText(txt1, "Average volume /trade : " + DoubleToString(av_volumes, 2) + " lots", 8, "Century Gothic", color2);

    txt1 = version + "210";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 320);
    }
    string expectancy;
    if (total_trades != 0) expectancy = DoubleToStr(total_profit / total_trades, 2);

    if (total_trades != 0 && total_profit / total_trades > 0) {
        ObjectSetText(txt1, "Payoff expectancy /trade : " + expectancy + curr, 8, "Century Gothic", color3);
    }
    if (total_trades != 0 && total_profit / total_trades < 0) {
        ObjectSetText(txt1, "Payoff expectancy /trade : " + expectancy + curr, 8, "Century Gothic", color4);
    }
    if (total_trades == 0) {
        ObjectSetText(txt1, "Payoff expectancy /trade : NA", 8, "Century Gothic", color3);
    }

    txt1 = version + "211";
    if (total_trades != 0 && profit_factor >= 1) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 332);
        }
        ObjectSetText(txt1, "Profit factor : " + DoubleToString(profit_factor, 2), 8, "Century Gothic", color3);
    }
    if (total_trades != 0 && profit_factor < 1) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 332);
        }
        ObjectSetText(txt1, "Profit factor : " + DoubleToString(profit_factor, 2), 8, "Century Gothic", color4);
    }
    if (total_trades == 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 332);
        }
        ObjectSetText(txt1, "Profit factor : NA", 8, "Century Gothic", color3);
    }
    //--- Earnings

    txt1 = version + "56";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 335);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "57";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 354);
    }
    ObjectSetText(txt1, "Earnings", 12, "Century Gothic", color1);

    txt1 = version + "58";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 360);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    double profitx = Earnings(0);
    txt1 = version + "300";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 380);
    }
    ObjectSetText(txt1, "Earnings today : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

    profitx = Earnings(1);
    txt1 = version + "301";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 392);
    }
    ObjectSetText(txt1, "Earnings yesterday : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

    profitx = Earnings(2);
    txt1 = version + "302";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 404);
    }
    ObjectSetText(txt1, "Earnings before yesterday : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

    txt1 = version + "303";
    if (total_profit >= 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 416);
        }
        ObjectSetText(txt1, "All time profit : " + DoubleToString(total_profit, 2) + curr, 8, "Century Gothic", color3);
    }
    if (total_profit < 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 416);
        }
        ObjectSetText(txt1, "All time loss : " + DoubleToString(total_profit, 2) + curr, 8, "Century Gothic", color4);
    }

    //--- Broker & Account

    txt1 = version + "59";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 419);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "60";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 70);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 438);
    }
    ObjectSetText(txt1, "Broker Information", 12, "Century Gothic", color1);

    txt1 = version + "61";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 443);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "400";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 463);
    }
    ObjectSetText(txt1, "Spread : " + DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0) + " pts [Max : " + DoubleToString(max_spread, 0) + " pts]", 8, "Century Gothic", color2);

    txt1 = version + "401";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 475);
    }
    ObjectSetText(txt1, "ID : " + AccountCompany(), 8, "Century Gothic", color2);

    txt1 = version + "402";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 487);
    }
    ObjectSetText(txt1, "Server : " + AccountServer(), 8, "Century Gothic", color2);

    txt1 = version + "403";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 499);
    }
    ObjectSetText(txt1, "Freeze lvl : " + IntegerToString(MarketInfo(Symbol(), MODE_FREEZELEVEL), 0) + " pts II Stop lvl : " + IntegerToString(MarketInfo(Symbol(), MODE_STOPLEVEL), 0) + " pts", 8, "Century Gothic", color2);

    txt1 = version + "404";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 511);
    }
    ObjectSetText(txt1, "L-Swap : " + DoubleToStr(MarketInfo(Symbol(), MODE_SWAPLONG), 2) + curr + "/lot II S-Swap : " + DoubleToStr(MarketInfo(Symbol(), MODE_SWAPSHORT), 2) + curr + "/lot", 8, "Century Gothic", color2);

    txt1 = version + "62";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 514);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "63";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 533);
    }
    ObjectSetText(txt1, "Account", 12, "Century Gothic", color1);

    txt1 = version + "64";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 538);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "500";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 558);
    }
    ObjectSetText(txt1, "ID : " + AccountName() + " [#" + IntegerToString(AccountNumber(), 0) + "]", 8, "Century Gothic", color2);

    txt1 = version + "501";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 570);
    }
    ObjectSetText(txt1, "Leverage : " + (string) AccountLeverage() + ":1", 8, "Century Gothic", color2);

    txt1 = version + "502";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 582);
    }
    ObjectSetText(txt1, "Currency : " + AccountCurrency() + " [" + curr + "]", 8, "Century Gothic", color2);
}

/*       ____________________________________________
         T                                          T
         T                WRITE NAME                T
         T__________________________________________T
*/

void EA_name() {
    string txt2 = version + "20";
    if (ObjectFind(txt2) == -1) {
        ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt2, OBJPROP_CORNER, 0);
        ObjectSet(txt2, OBJPROP_XDISTANCE, 30);
        ObjectSet(txt2, OBJPROP_YDISTANCE, 27);
    }
    ObjectSetText(txt2, "Horizon Break", 25, "Century Gothic", color1);

    txt2 = version + "21";
    if (ObjectFind(txt2) == -1) {
        ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt2, OBJPROP_CORNER, 0);
        ObjectSet(txt2, OBJPROP_XDISTANCE, 78);
        ObjectSet(txt2, OBJPROP_YDISTANCE, 68);
    }
    ObjectSetText(txt2, "by Edorenta || version " + version, 8, "Arial", Gray);

    txt2 = version + "22";
    if (ObjectFind(txt2) == -1) {
        ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt2, OBJPROP_CORNER, 0);
        ObjectSet(txt2, OBJPROP_XDISTANCE, 32);
        ObjectSet(txt2, OBJPROP_YDISTANCE, 51);
    }
    ObjectSetText(txt2, "___________________________", 11, "Arial", Gray);

    /*
       txt2 = version + "23";
       if (ObjectFind(txt2) == -1) {
          ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
          ObjectSet(txt2, OBJPROP_CORNER, 0);
          ObjectSet(txt2, OBJPROP_XDISTANCE, 32);
          ObjectSet(txt2, OBJPROP_YDISTANCE, 67);
       }
       ObjectSetText(txt2, "___________________________", 11, "Arial", Gray);

    */
}

/*       ____________________________________________
         T                                          T
         T                 THE END                  T
         T__________________________________________T
*/