import type {FinanceTotals} from './report-data';
import type {TeachingRecord} from './teaching-types';
export interface OverviewData {
 finance:FinanceTotals;serverNow:string;teachers:number;classes:number;pending:number;corrections:number;missing:number;total:number;
 recent:TeachingRecord[];activity:{dates:string[];from:string;to:string;start:string;end:string;minutes:number[]};
}
export function activityWindow(serverNow:string){
 const local=new Date(Date.parse(serverNow)+390*60000).toISOString().slice(0,10),midnight=Date.parse(local+'T00:00:00Z');
 const dates=Array.from({length:7},(_,i)=>new Date(midnight-(6-i)*86400000).toISOString().slice(0,10));
 return {dates,from:dates[0],to:local,start:new Date(midnight-6*86400000-390*60000).toISOString(),end:new Date(midnight+86400000-390*60000).toISOString()};
}
// Completed activity by effective Myanmar start date; never payroll eligibility.
export function addActivity(minutes:number[],dates:string[],rows:{start_at:string;end_at:string|null;minutes:number|null}[]){
 for(const row of rows){
  if(!row.end_at||row.minutes===null||!Number.isFinite(row.minutes)||row.minutes<0)continue;
  const day=new Date(Date.parse(row.start_at)+390*60000).toISOString().slice(0,10),index=dates.indexOf(day);
  if(index>=0)minutes[index]+=Number(row.minutes);
 }
 return minutes;
}
