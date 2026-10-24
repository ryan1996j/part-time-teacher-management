import type {DemoStore,Session,ClassRecord} from './demo-types';
declare const flow:{verificationQueue:(s:DemoStore)=>Session[];status:(s:Session)=>string;date:(value?:string)=>string;assignedClasses:(s:DemoStore,id:string)=>ClassRecord[];activity:(sessions:Session[])=>{dates:string[];hours:number[];from:string;to:string}};
export = flow;
