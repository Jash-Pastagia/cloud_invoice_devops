import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'

// Configure dayjs once and export the configured instance
dayjs.extend(relativeTime)

export default dayjs
