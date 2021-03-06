﻿// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

using System;
using System.Collections;
using System.Collections.Generic;

namespace Microsoft.EntityFrameworkCore.Tools.Internal
{
    public interface IOperationExecutor : IDisposable
    {
        IDictionary AddMigration(string name, string outputDir, string contextType);
        IEnumerable<string> RemoveMigration(string contextType, bool force);
        IEnumerable<IDictionary> GetMigrations(string contextType);
        void DropDatabase(string contextType);
        IDictionary GetContextInfo(string name);
        string GetContextType(string name);
        void UpdateDatabase(string migration, string contextType);
        IEnumerable<IDictionary> GetContextTypes();

        IEnumerable<string> ScaffoldContext(
            string provider,
            string connectionString,
            string outputDir,
            string dbContextClassName,
            IEnumerable<string> schemaFilters,
            IEnumerable<string> tableFilters,
            bool useDataAnnotations,
            bool overwriteFiles);

        string ScriptMigration(string fromMigration, string toMigration, bool idempotent, string contextType);
    }
}
