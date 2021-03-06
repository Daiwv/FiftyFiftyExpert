//+------------------------------------------------------------------+
//|                                           Area51MoneyManager.mq4 |
//|                                                           VBApps |
//|                                                 http://vbapps.co |
//+------------------------------------------------------------------+

#property copyright "Copyright © 2017 VBApps::Valeri Balachnin"
#property version   "1.0"
#property description "Helps to find the right money management."
#property strict

#define SLIPPAGE              5
#define NO_ERROR              1
#define AT_LEAST_ONE_FAILED   2

//--- input parameters
extern static string Trading="Base trading params";
extern double   LotSize=0.01;
extern bool     LotAutoSize=false;
extern int      LotRiskPercent=25;
extern int      MoneyRiskInPercent=0;
extern double   MaxDynamicLotSize=0.0;
extern int      MaxMoneyValueToLose=0;
extern int      CalculateForAllSymbols=true;
extern 

bool Debug=false;
bool DebugTrace=false;

/*licence*/
bool trial_lic=false;
datetime expiryDate=D'2017.10.01 00:00';
bool rent_lic=false;
datetime rentExpiryDate=D'2018.06.01 00:00';
int rentAccountNumber=0;
string rentCustomerName="";
/*licence_end*/

int countedDecimals=2;
double CurrentLoss=0;
double LotSizeP1;
double LotSizeP2;
double CurrentTotaLotSize;
double CurrentTotalLotSize=0.0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(LotSize<MarketInfo(Symbol(),MODE_MINLOT))
     {
      LotSize=MarketInfo(Symbol(),MODE_MINLOT);
     }
   if(LotSize>=MarketInfo(Symbol(),MODE_MAXLOT))
     {
      LotSize=MarketInfo(Symbol(),MODE_MAXLOT);
     }
     double lotstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   countedDecimals=(int)-MathLog10(lotstep);
   if(Debug)
     {
      Print("AccountNumber="+IntegerToString(AccountNumber()));
      Print("AccountCompany="+AccountCompany());
      Print("AccountName=",AccountName());
      Print("AccountServer=",AccountServer());
      Print("MODE_LOTSIZE=",MarketInfo(Symbol(),MODE_LOTSIZE),", Symbol=",Symbol());
      Print("MODE_MINLOT=",MarketInfo(Symbol(),MODE_MINLOT),", Symbol=",Symbol());
      Print("MODE_LOTSTEP=",MarketInfo(Symbol(),MODE_LOTSTEP),", Symbol=",Symbol());
      Print("MODE_MAXLOT=",MarketInfo(Symbol(),MODE_MAXLOT),", Symbol=",Symbol());
      Print("countedDecimals="+IntegerToString(countedDecimals));
     }
   if(trial_lic)
     {
      if(!IsTesting() && TimeCurrent()>expiryDate)
        {
         Alert("Expired copy. Please contact vendor.");
         return(INIT_FAILED);
           } else {
         ObjectCreate("TrialVersion",OBJ_LABEL,0,0,0);
         ObjectSetText("TrialVersion","End of a trial period: "+TimeToStr(expiryDate),11,"Calibri",clrAqua);
         ObjectSet("TrialVersion",OBJPROP_CORNER,1);
         ObjectSet("TrialVersion",OBJPROP_XDISTANCE,5);
         ObjectSet("TrialVersion",OBJPROP_YDISTANCE,15);
        }
     }

   if(rent_lic)
     {
      if(!IsTesting() && AccountName()==rentCustomerName && AccountNumber()==rentAccountNumber)
        {
         if(TimeCurrent()>rentExpiryDate)
           {
            Alert("Your license is expired. Please contact us.");
              } else {
            ObjectCreate("RentVersion",OBJ_LABEL,0,0,0);
            ObjectSetText("RentVersion","Your version is valid till: "+TimeToStr(rentExpiryDate),11,"Calibri",clrAqua);
            ObjectSet("RentVersion",OBJPROP_CORNER,1);
            ObjectSet("RentVersion",OBJPROP_XDISTANCE,5);
            ObjectSet("RentVersion",OBJPROP_YDISTANCE,15);

           }
           } else {
         if(!IsTesting())
           {
            Alert("You can use the expert advisor only on accountNumber="+IntegerToString(rentAccountNumber)+" and accountName="+rentCustomerName);
            Alert("Current accountNumber="+IntegerToString(AccountNumber())+" && accountName="+AccountName());
            return(INIT_FAILED);
           }
        }
     }
     //---
   return(INIT_SUCCEEDED);
  }   
 //+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete("CurProfit");
   ObjectDelete("NextLotSize");
   ObjectDelete("CurrentLoss");
  }    
  //+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
//risk management
   double SymbolStep=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   int MarginMode=(int)MarketInfo(Symbol(),MODE_MARGINCALCMODE);
   bool compareContractSizes=false;
   if(CompareDoubles(SymbolInfoDouble(Symbol(),SYMBOL_TRADE_CONTRACT_SIZE),100000.0)) {compareContractSizes=true;}
   else {compareContractSizes=false;}
   double RemainingLotSize=0.0;
   int countRemainingMaxLots=0;
   bool LotSizeIsBiggerThenMaxLot=false;
   double MaxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   if(SymbolStep>0.0)
     {
      MaxLot=NormalizeDouble(MaxLot-MathMod(MaxLot,SymbolStep),countedDecimals);
     }

   if(LotAutoSize)
     {
      int Faktor=100;
      if(LotRiskPercent<0.1 || LotRiskPercent>1000){Comment("Invalid Risk Value.");}
      else
        {
         if(getContractProfitCalcMode()==0 || (MarginMode==0 && compareContractSizes))
           {
            //Print("Fall1:"+(MarginMode==0 && compareContractSizes));
            LotSize=NormalizeDouble(MathFloor((AccountFreeMargin()*AccountLeverage()*LotRiskPercent*Point*Faktor)/
                                    (Ask*MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)))*MarketInfo(Symbol(),MODE_MINLOT),countedDecimals);
            //Print("LotSize="+LotSize);
            LotSizeP1 = NormalizeDouble(LotSize*0.625,countedDecimals);
            LotSizeP2 = NormalizeDouble(LotSize*0.5,countedDecimals);
           }
         else if((getContractProfitCalcMode()==1 || getContractProfitCalcMode()==2 || MarginMode==4) && (compareContractSizes==false))
           {
            //Print("Fall2:"+((getContractProfitCalcMode()==1 || getContractProfitCalcMode()==2 || MarginMode==4) && (compareContractSizes==false)));
            if(SymbolInfoDouble(Symbol(),SYMBOL_TRADE_CONTRACT_SIZE)==1.0){countedDecimals=0;}
            int Splitter=1000;
            if(getContractProfitCalcMode()==1){Splitter=100000;}
            if(MarginMode==4 && MarketInfo(Symbol(),MODE_TICKSIZE)==0.001){Splitter=1000000;}
            if(Digits==3){Faktor=1;}
            if(Digits==2){Faktor=10;}
            LotSize=NormalizeDouble(MathFloor((AccountFreeMargin()*AccountLeverage()*LotRiskPercent*Faktor*Point)/
                                    (Ask*MarketInfo(Symbol(),MODE_TICKSIZE)*MarketInfo(Symbol(),MODE_MINLOT)))*MarketInfo(Symbol(),MODE_MINLOT)/Splitter,countedDecimals);
            LotSizeP1 = MathFloor(NormalizeDouble(LotSize*0.625,countedDecimals));
            LotSizeP2 = MathFloor(NormalizeDouble(LotSize*0.5,countedDecimals));
            //Print("LotSize2="+LotSize);
            if(SymbolStep>0.0)
              {
               LotSize=LotSize-MathMod(LotSize,SymbolStep);
               LotSizeP1=LotSizeP1-MathMod(LotSizeP1,SymbolStep);
               LotSizeP2=LotSizeP2-MathMod(LotSizeP2,SymbolStep);
              }
              } else {
            Print("Cannot calculate the right auto lot size!");
            LotSize=MarketInfo(Symbol(),MODE_MINLOT);
            LotSizeP1=MarketInfo(Symbol(),MODE_MINLOT);
            LotSizeP2=MarketInfo(Symbol(),MODE_MINLOT);
           }
        }

      if(MaxDynamicLotSize>0 && LotSize>MaxDynamicLotSize)
        {
         LotSize=MaxDynamicLotSize;
        }
     }
   if(LotAutoSize==false){LotSize=LotSize;}
   if(LotSize<MarketInfo(Symbol(),MODE_MINLOT))
     {
      LotSize=MarketInfo(Symbol(),MODE_MINLOT);
      LotSizeP1 = NormalizeDouble(LotSize*0.625,countedDecimals);
      LotSizeP2 = NormalizeDouble(LotSize*0.5,countedDecimals);
      if(SymbolStep>0.0)
        {
         LotSize=NormalizeDouble(LotSize-MathMod(LotSize,SymbolStep),countedDecimals);
         LotSizeP1=NormalizeDouble(LotSizeP1-MathMod(LotSizeP1,SymbolStep), countedDecimals);
         LotSizeP2=NormalizeDouble(LotSizeP2-MathMod(LotSizeP2,SymbolStep), countedDecimals);
        }
     }
   if(LotSize>MaxLot)
     {
      countRemainingMaxLots=(int)(LotSize/MaxLot);
      RemainingLotSize=MathMod(LotSize,MaxLot);
      LotSizeIsBiggerThenMaxLot=true;
      CurrentTotalLotSize=LotSize;
      LotSize=MarketInfo(Symbol(),MODE_MAXLOT);
      LotSizeP1=NormalizeDouble(LotSizeP1*0.625,countedDecimals);
      LotSizeP2=NormalizeDouble(LotSizeP2*0.5,countedDecimals);
      if(SymbolStep>0.0)
        {
         LotSize=NormalizeDouble(LotSize-MathMod(LotSize,SymbolStep),countedDecimals);
         LotSizeP1=NormalizeDouble(LotSizeP1-MathMod(LotSizeP1,SymbolStep), countedDecimals);
         LotSizeP2=NormalizeDouble(LotSizeP2-MathMod(LotSizeP2,SymbolStep), countedDecimals);
        }
     }

   if(Debug)
     {
      Print("LotSize="+DoubleToStr(LotSize,countedDecimals));
      Print("LotSize*0,625="+DoubleToStr(LotSizeP1,countedDecimals));
      Print("LotSize*0,5="+DoubleToStr(LotSizeP2,countedDecimals));
     }

//Money Management
   double TempLoss=0;
   for(int j=0;j<OrdersTotal();j++)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderSymbol()==Symbol())
           {
            TempLoss=TempLoss+OrderProfit();
           }
        }
     }
   if(AccountBalance()>0)
     {
      CurrentLoss=NormalizeDouble((TempLoss/AccountBalance())*100,2);
     }
   if((MoneyRiskInPercent>0 && StrToInteger(DoubleToStr(MathAbs(CurrentLoss),0))>MoneyRiskInPercent) 
   || (MaxMoneyValueToLose>0 && StrToInteger(DoubleToStr(MathAbs(TempLoss),0))>MaxMoneyValueToLose))
     {
      while(CloseAll()==AT_LEAST_ONE_FAILED)
        {
         Sleep(1000);
         Print("Order close failed - retrying error: #"+IntegerToString(GetLastError()));
        }
     }
     
   double TempProfit=0;
   for(int j=0;j<OrdersTotal();j++)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderSymbol()==Symbol())
           {
            TempProfit=TempProfit+OrderProfit()+OrderCommission()+OrderSwap();
            if(Debug){Print("TempProfit="+DoubleToStr(TempProfit));}
           }
        }
     }
     CurrentProfit(TempProfit);
}
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=AccountBalance();
   return(ret);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CurrentProfit(double CurProfit)
  {
   ObjectCreate("CurProfit",OBJ_LABEL,0,0,0);
   if(CurProfit>=0.0)
     {
      ObjectSetText("CurProfit","EA Profit: "+DoubleToString(CurProfit,2)+" "+AccountCurrency(),11,"Calibri",clrLime);
        }else{ObjectSetText("CurProfit","EA Profit: "+DoubleToString(CurProfit,2)+" "+AccountCurrency(),11,"Calibri",clrOrangeRed);
     }
   ObjectSet("CurProfit",OBJPROP_CORNER,1);
   ObjectSet("CurProfit",OBJPROP_XDISTANCE,5);
   ObjectSet("CurProfit",OBJPROP_YDISTANCE,40);

   ObjectCreate("NextLotSize",OBJ_LABEL,0,0,0);
   if(CurrentTotalLotSize>0.0)
     {ObjectSetText("NextLotSize","NextLotSize: "+DoubleToString(CurrentTotalLotSize,2),11,"Calibri",clrLightYellow);}
   else {ObjectSetText("NextLotSize","NextLotSize: "+DoubleToString(LotSize,2),11,"Calibri",clrLightYellow);}
   ObjectSet("NextLotSize",OBJPROP_CORNER,1);
   ObjectSet("NextLotSize",OBJPROP_XDISTANCE,5);
   ObjectSet("NextLotSize",OBJPROP_YDISTANCE,80);
/*ObjectCreate("EAName",OBJ_LABEL,0,0,0);
   ObjectSetText("EAName","EAName: "+EAName,11,"Calibri",clrGold);
   ObjectSet("EAName",OBJPROP_CORNER,1);
   ObjectSet("EAName",OBJPROP_XDISTANCE,5);
   ObjectSet("EAName",OBJPROP_YDISTANCE,75);*/

   if(CurrentLoss<0.0)
     {
      ObjectCreate("CurrentLoss",OBJ_LABEL,0,0,0);
      ObjectSetText("CurrentLoss","Current loss in %: "+DoubleToString(CurrentLoss,2),11,"Calibri",clrDeepPink);
      ObjectSet("CurrentLoss",OBJPROP_CORNER,1);
      ObjectSet("CurrentLoss",OBJPROP_XDISTANCE,5);
      ObjectSet("CurrentLoss",OBJPROP_YDISTANCE,100);
        } else {ObjectDelete("CurrentLoss");
     }

   if(!IsTesting() && trial_lic && TimeCurrent()>expiryDate) {ExpertRemove();}
   if(!IsTesting() && rent_lic && TimeCurrent()>rentExpiryDate) {ExpertRemove();}
}

//+------------------------------------------------------------------+
int CloseAll()
  {
   bool rv=NO_ERROR;
   int numOfOrders=OrdersTotal();
   int FirstOrderType=0;

   for(int index=0; index<OrdersTotal(); index++)
     {
      bool oS=OrderSelect(index,SELECT_BY_POS,MODE_TRADES);
      if(OrderSymbol()==Symbol())
        {
         FirstOrderType=OrderType();
         break;
        }
     }

   for(int index=numOfOrders-1; index>=0; index--)
     {
      bool oS=OrderSelect(index,SELECT_BY_POS,MODE_TRADES);

      if(OrderSymbol()==Symbol())
         switch(OrderType())
           {
            case OP_BUY:
               if(!OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),SLIPPAGE,Red))
               rv=AT_LEAST_ONE_FAILED;
               break;

            case OP_SELL:
               if(!OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),SLIPPAGE,Red))
               rv=AT_LEAST_ONE_FAILED;
               break;

            case OP_BUYLIMIT:
            case OP_SELLLIMIT:
            case OP_BUYSTOP:
            case OP_SELLSTOP:
               if(!OrderDelete(OrderTicket()))
               rv=AT_LEAST_ONE_FAILED;
               break;
           }
     }

   return(rv);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool CompareDoubles(double number1,double number2)
  {
   if(NormalizeDouble(number1-number2,5)==0) return(true);
   else return(false);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getContractProfitCalcMode()
  {
   int profitCalcMode=(int)MarketInfo(Symbol(),MODE_PROFITCALCMODE);
   return profitCalcMode;
  }