# Set variables
echo UMBRACO 9 DEMO INSTALL
demoNameDefault='umbracov9-demo-'$RANDOM

# Get the demo name from the user
echo
echo Demo name should be only contain alphanumerics and hyphens. It Can''t start or end with hyphen. It should be less than 15 characters in length and globally unique. This will be the name of your web app.
read -p "Enter demo name [$demoNameDefault]: " input
demoName="${input:-$demoNameDefault}"
echo Demo Name: $demoName

# Check if the random password should be saved or displayed on screen
echo
echo Passwords are created with a random value. Do you want to view or save them to a file?
read -p "Credentials (save/display/both/none)[both]: " input
outputCredentials="${input:-both}"
echo Output credentials: $outputCredentials

# Run everything inside this folder
mkdir $demoName
cd $demoName

groupName="rg-"$demoName
location=australiaeast
serverName="sqlServer-"$demoName
adminUser="serveradmin"
adminPassword="High5Ur0ck#"$RANDOM
dbName="sqlDb-"$demoName
dbUser="umbracoDbo"
appServiceName="app-"$demoName
deployUserName="u9deployer"
deployPassword="woofW00F#9"$RANDOM
umbracoAdminUserName="DemoUser"
umbracoAdminEmail="demo.user@monumentmail.com"
umbracoAdminPassword="UNatt3nd3d#dotnet5"$RANDOM

# Create resource group to contain this demo
echo Creating resource Group $groupName...
az group create --name $groupName --location $location

# Create a SQL server instance
echo Creating SQL server instance...
az sql server create --admin-password $adminPassword --admin-user $adminUser --location $location --name $serverName --resource-group $groupName

az sql server firewall-rule create --resource-group $groupName --server $serverName --name AllowAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create the SQL server database
echo Creating SQL database instance...
az sql db create --name $dbName --resource-group $groupName --server $serverName --service-objective S0

# Get the connection string for the database
connectionString=$(az sql db show-connection-string --name $dbName --server $serverName --client ado.net --output tsv)

# Add credentials to the connection string
connectionString=${connectionString//<username>/$adminUser}
connectionString=${connectionString//<password>/$adminPassword}

# Create an Linux App Service plan in the B1 (Basic small) tier.
echo Creating Linux App Service plan...
az appservice plan create --name $appServiceName --resource-group $groupName --sku B1 --is-linux

# Create a web app
echo Creating Web App...
az webapp create --name $demoName --resource-group $groupName --plan  $appServiceName --runtime "DOTNET|5.0"

# Set WebApp Deployment User
az webapp deployment user set --user-name $deployUserName --password $deployPassword

# Install the .NET 5 SDK
echo Installing .NET 5 SDK on this cloud shell...
mkdir dotnetinstall
cd dotnetinstall
wget https://download.visualstudio.microsoft.com/download/pr/b77183fa-c045-4058-82c5-d37742ed5f2d/ddaccef3e448a6df348cae4d1d271339/dotnet-sdk-5.0.403-linux-x64.tar.gz

DOTNET_FILE=dotnet-sdk-5.0.403-linux-x64.tar.gz
export DOTNET_ROOT=$(pwd)/dotnet

mkdir -p "$DOTNET_ROOT" && tar zxf "$DOTNET_FILE" -C "$DOTNET_ROOT"

export PATH=$DOTNET_ROOT:$PATH

cd ..

# Set Umbraco Unattended install variables
echo Setting unattended install variables on the web app config
az webapp config connection-string set --resource-group $groupName --name $demoName --settings umbracoDbDSN="$connectionString" --connection-string-type SQLAzure

az webapp config connection-string set --resource-group $groupName --name $demoName --settings umbracoDbDSN="$connectionString" --connection-string-type SQLAzure

az webapp config appsettings set --resource-group $groupName --name $demoName --settings UMBRACO__CMS__GLOBAL__INSTALLMISSINGDATABASE=true UMBRACO__CMS__UNATTENDED__INSTALLUNATTENDED=true UMBRACO__CMS__UNATTENDED__UNATTENDEDUSERNAME="$umbracoAdminUserName" UMBRACO__CMS__UNATTENDED__UNATTENDEDUSEREMAIL="$umbracoAdminEmail" UMBRACO__CMS__UNATTENDED__UNATTENDEDUSERPASSWORD="$umbracoAdminPassword"

# Install Umbraco unattended
# Source - https://gist.github.com/nul800sebastiaan/1553316fda85011270ce2bde35243e5b
echo Create new Umbraco solution on Cloud Shell...
dotnet new -i Umbraco.Templates
dotnet new umbraco -n UmbracoUnattended
cd UmbracoUnattended

dotnet add package Umbraco.TheStarterKit

# Publish the Umbraco sample site
echo Publish the Umbraco Site...
dotnet publish --output release
cd ./release
zip -r ../release.zip .
cd ..

echo Deploy site to Azure Web App...
az webapp deploy --resource-group $groupName --name $demoName --src-path ./release.zip

echo Writing script to help deletion later...
echo "# Once done, delete the entire resource group to keep costs down" > delete-demo.sh
echo "echo Deleting resource group..." >> delete-demo.sh
echo "az group delete --name $groupName --yes" >> delete-demo.sh
chmod +x delete-demo.sh

echo Trying to access the site for the first time...
siteUrl=https://$(az webapp show --resource-group $groupName --name $demoName --query defaultHostName --output tsv)
wget $siteUrl

# Output credentials if requested
echo
echo Saving/displaying credentials...
if $outputCredentials="none";
then
echo Credentials are NOT saved/displayed as requested
fi

if $outputCredentials="save" || $outputCredentials="both";
then
echo Saving credentials as requested
echo "Site URL: $siteUrl" > credentials.txt
echo "Database Admin Username: $adminUser" >> credentials.txt
echo "Database Admin Password: $adminPassword" >> credentials.txt
echo "Deployment Username: $deployUserName" >> credentials.txt
echo "Deployment Password: $deployPassword" >> credentials.txt
echo "Umbraco Admin Username: $umbracoAdminEmail" >> credentials.txt
echo "Umbraco Admin Password: $umbracoAdminPassword" >> credentials.txt
echo "Saved credentials.txt file"
fi

if $outputCredentials="display" || $outputCredentials="both";
then
echo Displaying credentials as requested
echo "Site URL: $siteUrl"
echo "Database Admin Username: $adminUser"
echo "Database Admin Password: $adminPassword"
echo "Deployment Username: $deployUserName"
echo "Deployment Password: $deployPassword"
echo "Umbraco Admin Username: $umbracoAdminEmail"
echo "Umbraco Admin Password: $umbracoAdminPassword"
fi

echo 
echo Demo site install complete. The first load may take a moment. Go to $siteUrl The first load may take a moment.
