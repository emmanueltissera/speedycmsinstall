#!/bin/bash
echo "UMBRACO 12 RC1 DEMO INSTALL"

# Set the default name for this demo
demoNameDefault='umbracov12rc1-demo-'$RANDOM

# Get the demo name from the user
echo 
echo "Demo name should only contain alphanumerics and hyphens. It Can't start or end with a hyphen. It should be less than 15 characters in length and globally unique. This will be the name of your web app."
read -p "Enter demo name [$demoNameDefault]: " input
demoName="${input:-$demoNameDefault}"
echo "Demo name in use: $demoName"

# Check if the random passwords should be saved or displayed on screen
echo
echo "Passwords are created with a random value. Do you want to view or save them to a file?"
read -p "Credentials (save/display/both/none)[both]: " input
outputCredentials="${input:-both}"
echo "Output credentials: $outputCredentials"

# Run everything inside this folder for easy clean-up
mkdir "$demoName"
cd "$demoName" || exit

# Set variables
groupName="rg-"$demoName
location=australiaeast
serverName="sqlServer-"$demoName
adminUser="serveradmin"
adminPassword="High5Ur0ck#"$RANDOM$RANDOM
dbName="sqlDb-"$demoName
appServiceName="app-"$demoName
deployUserName="u12rc1deployer"
deployPassword="woofW00F#12rc1"$RANDOM$RANDOM
umbracoAdminUserName="DemoUser"
umbracoAdminEmail="demo.user@monumentmail.com"
umbracoAdminPassword="UNatt3nd3d#dotnet7"$RANDOM$RANDOM
deleteScriptFile="delete-demo-$demoName.sh"
umbracoDeliveryApiKey="headless-peeps#"$RANDOM$RANDOM

# Create a resource group to contain this demo
echo "Creating Resource Group $groupName..."
az group create --name "$groupName" --location "$location"

# Create a SQL server instance
echo "Creating SQL server instance..."
az sql server create --admin-password "$adminPassword" --admin-user "$adminUser" --location "$location" --name "$serverName" --resource-group "$groupName"

az sql server firewall-rule create --resource-group "$groupName" --server "$serverName" --name AllowAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create the SQL server database
echo "Creating SQL database instance..."
az sql db create --name "$dbName" --resource-group "$groupName" --server "$serverName" --service-objective S0

# Get the connection string for the database
connectionString=$(az sql db show-connection-string --name "$dbName" --server "$serverName" --client ado.net --output tsv)

# Add credentials to the connection string
connectionString=${connectionString//<username>/$adminUser}
connectionString=${connectionString//<password>/$adminPassword}

# Create a Linux App Service plan in the B1 (Basic small) tier.
echo "Creating Linux App Service plan..."
az appservice plan create --name "$appServiceName" --resource-group "$groupName" --sku B1 --is-linux

# Create a web app
echo "Creating Web App..."
az webapp create --name "$demoName" --resource-group "$groupName" --plan  "$appServiceName" --runtime "DOTNETCORE:7.0"

# Set WebApp Deployment User
echo "Setting WebApp deployment user..."
az webapp deployment user set --user-name "$deployUserName" --password "$deployPassword"

# Install the .NET 7 SDK
echo "Installing .NET 7 SDK on this cloud shell..."
mkdir dotnetinstall
cd dotnetinstall || exit

wget https://download.visualstudio.microsoft.com/download/pr/351400ef-f2e6-4ee7-9d1b-4c246231a065/9f7826270fb36ada1bdb9e14bc8b5123/dotnet-sdk-7.0.302-linux-x64.tar.gz

DOTNET_FILE=dotnet-sdk-7.0.302-linux-x64.tar.gz
DOTNET_ROOT=$(pwd)/dotnet
export DOTNET_ROOT

mkdir -p "$DOTNET_ROOT" && tar zxf "$DOTNET_FILE" -C "$DOTNET_ROOT"

export PATH=$DOTNET_ROOT:$PATH

cd ..


# Set Umbraco Unattended install variables
echo "Setting unattended install variables on the web app config..."
az webapp config connection-string set --resource-group "$groupName" --name "$demoName" --settings umbracoDbDSN="$connectionString" --connection-string-type SQLAzure

az webapp config appsettings set --resource-group "$groupName" --name "$demoName" --settings UMBRACO__CMS__GLOBAL__INSTALLMISSINGDATABASE=true UMBRACO__CMS__UNATTENDED__INSTALLUNATTENDED=true UMBRACO__CMS__UNATTENDED__UNATTENDEDUSERNAME="$umbracoAdminUserName" UMBRACO__CMS__UNATTENDED__UNATTENDEDUSEREMAIL="$umbracoAdminEmail" UMBRACO__CMS__UNATTENDED__UNATTENDEDUSERPASSWORD="$umbracoAdminPassword" Umbraco__CMS__DeliveryApi__Enabled=true Umbraco__CMS__DeliveryApi__PublicAccess=true Umbraco__CMS__DeliveryApi__ApiKey="$umbracoDeliveryApiKey" Umbraco__CMS__DeliveryApi__DisallowedContentTypeAliases="[]" Umbraco__CMS__DeliveryApi__RichTextOutputAsJson=true

# Create Umbraco Project
echo "Create a new Umbraco project on this cloud shell..."
dotnet new -i Umbraco.Templates::12.0.0-rc1
dotnet new umbraco --force -n "UmbracoUnattended"
cd UmbracoUnattended || exit

#Add starter kit
dotnet add package Umbraco.TheStarterKit

# Publish the Umbraco sample site
echo 
echo "Publish the Umbraco site..."
dotnet publish --output release
cd ./release || exit
zip -r ../release.zip .
cd ..

# Deploy the Umbraco sample site
echo 
echo "Deploy site to Azure Web App..."
  az webapp deployment source config-zip --resource-group "$groupName" --name "$demoName" --src ./release.zip

# Get the site URL
siteUrl="https://"$(az webapp show --resource-group "$groupName" --name "$demoName" --query defaultHostName --output tsv)

# Output credentials if requested
cd ..
echo
if [[ "$outputCredentials" == "none" ]];
then
echo "Credentials are NOT saved/displayed as requested"
fi

if [[ "$outputCredentials" == "save" || "$outputCredentials" == "both" ]];
then
echo 
echo "Saving credentials as requested"
{
  echo "Site URL: $siteUrl"
  echo 
  echo "Database Admin Username: $adminUser"
  echo "Database Admin Password: $adminPassword"
  echo "Deployment Username: $deployUserName"
  echo "Deployment Password: $deployPassword"
  echo "Umbraco Admin Username: $umbracoAdminEmail"
  echo "Umbraco Admin Password: $umbracoAdminPassword"
  echo "Umbraco Delivery API Key: $umbracoDeliveryApiKey"
} > credentials.txt
echo "Saved $demoName/credentials.txt file"
fi

if [[ "$outputCredentials" == "display" || "$outputCredentials" == "both" ]];
then
echo 
echo "Displaying credentials as requested"
echo "Site URL: $siteUrl"
echo
echo "Database Admin Username: $adminUser"
echo "Database Admin Password: $adminPassword"
echo "Deployment Username: $deployUserName"
echo "Deployment Password: $deployPassword"
echo "Umbraco Admin Username: $umbracoAdminEmail"
echo "Umbraco Admin Password: $umbracoAdminPassword"
echo "Umbraco Delivery API Key: $umbracoDeliveryApiKey" 
fi

# Write script for deletion
cd ..
echo 
echo "Writing script to help deletion later..."
{
  echo "#!/bin/bash"
  echo "echo UMBRACO 12 RC1 DEMO CLEAN UP"
  echo
  echo "# Once done, delete the entire resource group to keep costs down"
  echo "echo Deleting resource group..."
  echo "az group delete --name $groupName --yes"
  echo 
  echo "# delete the folder"
  echo "echo Deleting install folder..."
  echo "rm -r $demoName"
} > "$deleteScriptFile"
chmod +x "$deleteScriptFile"
echo "Delete script location - $deleteScriptFile"

# Bootstrap the site with an initial request
echo 
echo "Trying to access the site for the first time..."
curl -s -o /dev/null -w "%{http_code}" "$siteUrl"

# Provide the site URL to click through
echo 
echo "Demo site install complete. Go to $siteUrl"
