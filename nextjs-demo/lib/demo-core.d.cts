import type {DemoStore,DemoData} from './demo-types';
declare const core:{Store:new(data?:DemoData|null)=>DemoStore;mins:(start:string,end:string|null)=>number;money:(minutes:number,rate:number|null)=>number};
export = core;
