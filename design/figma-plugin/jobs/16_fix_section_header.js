// Fix: a Section header keeps the app's 44 px minimum height without its action.
await cbSetup();
const set = await comp('Section header');
for (const v of set.children) v.minHeight = 44;
return set.children.map((v) => [v.name, v.minHeight]);
