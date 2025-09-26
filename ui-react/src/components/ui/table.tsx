import * as React from 'react'
import { clsx } from 'clsx'

export const Table = ({ className, ...props }: React.HTMLAttributes<HTMLTableElement>) => (
  <table className={clsx('w-full caption-bottom text-sm', className)} {...props} />
)
export const TableHeader = (props: React.HTMLAttributes<HTMLTableSectionElement>) => <thead {...props} />
export const TableBody = (props: React.HTMLAttributes<HTMLTableSectionElement>) => <tbody {...props} />
export const TableRow = ({ className, ...props }: React.HTMLAttributes<HTMLTableRowElement>) => (
  <tr className={clsx('border-b transition-colors hover:bg-muted/50 data-[state=selected]:bg-muted', className)} {...props} />
)
export const TableHead = ({ className, ...props }: React.ThHTMLAttributes<HTMLTableCellElement>) => (
  <th className={clsx('h-12 px-4 text-left align-middle font-medium text-muted-foreground [&:has([role=checkbox])]:pr-0', className)} {...props} />
)
export const TableCell = ({ className, ...props }: React.TdHTMLAttributes<HTMLTableCellElement>) => (
  <td className={clsx('p-4 align-middle [&:has([role=checkbox])]:pr-0', className)} {...props} />
)
export default Table
