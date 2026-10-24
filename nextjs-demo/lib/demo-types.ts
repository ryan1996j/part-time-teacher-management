export interface Teacher{id:string;name:string;email:string;active:boolean;tone:number;assignments:string[];rates:{from:string;rate:number}[]}
export interface ClassRecord{id:string;name:string;subject:string;active:boolean}
export interface Session{id:string;teacher:string;classId:string;start:string;end:string|null;originalStart:string;originalEnd:string|null;status:string;source:string;version:number;note?:string;flag?:string;reviewNote?:string}
export interface Correction{id:string;session:string;start:string;end:string;reason:string;status:string;comment:string}
export interface DemoData{schema:number;teachers:Teacher[];classes:ClassRecord[];sessions:Session[];corrections:Correction[];runs:unknown[];payments:unknown[];audit:unknown[]}
export interface DemoStore{data:DemoData;reason(s:Session):string;rate(s:Session):number|null;locked(s:Session):boolean;pending(s:Session):boolean;teacher(id:string):Teacher;session(id:string):Session;addSession(t:string,c:string,s:string,e:string,r:string):Session}
