/**
 * Search Users Lambda Function
 * Searches Cognito users by name or email
 */

const { CognitoIdentityProviderClient, ListUsersCommand } = require('@aws-sdk/client-cognito-identity-provider');

const client = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION || 'us-east-1' });
const USER_POOL_ID = process.env.USER_POOL_ID || 'us-east-1_aJN47Jgfy';

exports.handler = async (event) => {
    console.log('Search Users Request:', JSON.stringify(event, null, 2));
    
    // Parse request
    let body;
    try {
        body = JSON.parse(event.body);
    } catch (error) {
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Invalid request body' })
        };
    }
    
    const { searchQuery } = body;
    
    if (!searchQuery || searchQuery.trim().length < 2) {
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Search query must be at least 2 characters' })
        };
    }
    
    try {
        // Search users in Cognito
        const command = new ListUsersCommand({
            UserPoolId: USER_POOL_ID,
            Limit: 20 // Max results
        });
        
        const response = await client.send(command);
        
        // Filter and format results
        const users = response.Users
            .filter(user => {
                // Get user attributes
                const nameAttr = user.Attributes?.find(attr => attr.Name === 'name');
                const emailAttr = user.Attributes?.find(attr => attr.Name === 'email');
                
                const name = nameAttr?.Value || '';
                const email = emailAttr?.Value || '';
                const query = searchQuery.toLowerCase();
                
                // Match name or email
                return name.toLowerCase().includes(query) || 
                       email.toLowerCase().includes(query);
            })
            .map(user => {
                // Extract user info
                const subAttr = user.Attributes?.find(attr => attr.Name === 'sub');
                const nameAttr = user.Attributes?.find(attr => attr.Name === 'name');
                const emailAttr = user.Attributes?.find(attr => attr.Name === 'email');
                
                return {
                    userId: subAttr?.Value,
                    name: nameAttr?.Value || 'Unknown',
                    email: emailAttr?.Value || ''
                };
            })
            .filter(user => user.userId); // Only include users with valid ID
        
        console.log(`Found ${users.length} users matching "${searchQuery}"`);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                users: users,
                count: users.length
            })
        };
        
    } catch (error) {
        console.error('Error searching users:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: false,
                error: 'Failed to search users',
                message: error.message
            })
        };
    }
};

