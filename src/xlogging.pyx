#-------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for
# license information.
#--------------------------------------------------------------------------

# Python imports
from enum import Enum
import logging
import io

# C imports
from libc.stdlib cimport malloc, free
cimport c_xlogging


_logger = logging.getLogger('uamqp.c_uamqp')


class LogCategory(Enum):
    Error = c_xlogging.LOG_CATEGORY_TAG.AZ_LOG_ERROR
    Info = c_xlogging.LOG_CATEGORY_TAG.AZ_LOG_INFO
    Debug = c_xlogging.LOG_CATEGORY_TAG.AZ_LOG_TRACE


cdef char* vprintf_alloc(const char* format, c_xlogging.va_list va):
    cdef char* result
    cdef int neededSize
    neededSize = c_xlogging.vsnprintf(NULL, 0, format, va)
    if neededSize < 0:
        result = NULL
    else:
        result = <char*>malloc(neededSize + 1)
        if <void*>result != NULL:
            if c_xlogging.vsnprintf(result, neededSize + 1, format, va) != neededSize:
                free(result)
                result = NULL
    return result;


cdef void custom_logging_function(c_xlogging.LOG_CATEGORY_TAG log_category, const char* file, const char* func, const int line, unsigned int options, const char* format, ...):
    log_level = LogCategory(log_category)
    cdef c_xlogging.va_list args
    cdef char* text
    c_xlogging.va_start(args, format)
    text = vprintf_alloc(format, args)
    if <void*>text != NULL:
        _python_log(log_level, text, bool(options), file=file, func=func, line=line)
    c_xlogging.va_end(args)
    free(text)


cpdef set_python_logger():
    c_xlogging.xlogging_set_log_function(<c_xlogging.LOGGER_LOG>custom_logging_function)


def _python_log(category, text, end, text_bldr=[], file=None, func=None, line=None):
    text_bldr.append(text)
    if not end:
        return

    log_line = b''
    while text_bldr:
        log_line += text_bldr.pop(0)
    if category == LogCategory.Debug or category == LogCategory.Info:
        _logger.info(log_line)
    else:
        _logger.debug("{} ({}:{}:{})".format(
            log_line, file, func, line))