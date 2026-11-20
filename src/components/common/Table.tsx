import React from 'react'

export interface Column<T> {
  key: keyof T | string
  header: string
  render?: (value: any, item: T) => React.ReactNode
  className?: string
}

export interface TableProps<T> {
  data: T[]
  columns: Column<T>[]
  onRowClick?: (item: T) => void
  emptyMessage?: string
  className?: string
}

function Table<T extends object>({
  data,
  columns,
  onRowClick,
  emptyMessage = 'No hay datos disponibles',
  className = ''
}: TableProps<T>) {
  if (data.length === 0) {
    return (
      <div className="text-center py-8 text-gray-400">
        {emptyMessage}
      </div>
    )
  }

  return (
    <div className={`overflow-x-auto ${className}`}>
      <table className="w-full">
        <thead className="bg-gray-700">
          <tr>
            {columns.map((column) => (
              <th
                key={String(column.key)}
                className={`
                  px-4 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider
                  ${column.className || ''}
                `}
              >
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-700">
          {data.map((item, index) => (
            <tr
              key={index}
              className={`
                hover:bg-gray-700 transition-colors
                ${onRowClick ? 'cursor-pointer' : ''}
              `}
              onClick={() => onRowClick?.(item)}
            >
              {columns.map((column) => (
                <td
                  key={String(column.key)}
                  className={`
                    px-4 py-3 text-sm text-gray-300
                    ${column.className || ''}
                  `}
                >
                  {column.render 
                    ? column.render(item[column.key as keyof T], item)
                    : String(item[column.key as keyof T] || '')
                  }
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default Table