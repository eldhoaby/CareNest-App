const fs = require('fs');
const path = require('path');

const libPath = path.join(__dirname, 'lib');

const colorMap = {
    'Color(0xFFEF4444)': 'AppColors.danger',
    'Color(0xFFDC2626)': 'AppColors.danger',
    'Color(0xFFF59E0B)': 'AppColors.warning',
    'Color(0xFF22C55E)': 'AppColors.success',
    'Color(0xFF10B981)': 'AppColors.success',
    'Color(0xFF6366F1)': 'AppColors.primarySoft',
    'Color(0xFF2563EB)': 'AppColors.primary',
    'Color(0xFFE5E7EB)': 'AppColors.border',
    'Color(0x10000000)': 'Color(0x11000000)', // Soft shadow fix
    'Color(0xFF0F172A)': 'AppColors.textPrimary',
};

// Recursive file walker
function walkSync(dir, filelist = []) {
    fs.readdirSync(dir).forEach(file => {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            filelist = walkSync(fullPath, filelist);
        } else {
            if (fullPath.endsWith('.dart')) {
                filelist.push(fullPath);
            }
        }
    });
    return filelist;
}

const dartFiles = walkSync(libPath);
let modifiedFilesCount = 0;

for (const file of dartFiles) {
    let content = fs.readFileSync(file, 'utf8');
    let original = content;

    for (const [hex, appColor] of Object.entries(colorMap)) {
        // Regex to replace exact instance of the hex, allowing for `const` before it occasionally
        const regex = new RegExp(`const\\s+${hex.replace(/[\\(\\)]/g, '\\$&')}|${hex.replace(/[\\(\\)]/g, '\\$&')}`, 'g');
        content = content.replace(regex, appColor);
    }
    
    // Auto import AppColors if we added it and it's missing
    if (content !== original) {
        if (content.includes('AppColors.') && !content.includes('app_colors.dart')) {
            // we skip adding the import for now, assuming mostly it's already there or we just fix it if compiler complains.
            // Actually, let's inject import if missing, looking at relative depth
            const depth = file.split(path.sep).length - libPath.split(path.sep).length;
            let importPath = '';
            for(let i=0; i<depth; i++) importPath += '../';
            importPath += 'core/constants/app_colors.dart';
            
            const importStmt = `import '${importPath}';\n`;
            if (!content.includes('app_colors.dart')) {
                // insert after first import
                content = content.replace(/(import\s+[^;]+;\n)/, `$1${importStmt}`);
            }
        }

        // Fix double const AppColors.something errors
        content = content.replace(/const\s+AppColors\./g, 'AppColors.');

        fs.writeFileSync(file, content, 'utf8');
        modifiedFilesCount++;
        console.log(`Updated ${file}`);
    }
}

console.log(`\nAudit completed. Modified ${modifiedFilesCount} files.`);
