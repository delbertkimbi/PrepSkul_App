#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>

// --- Helper Functions ---

// Function to generate and fill an array with random numbers.
void generate_random_array(int arr[], int n) {
    // We use a fixed seed for reproducibility, so you get the same array every time.
    srand(12345);
    for (int i = 0; i < n; i++) {
        arr[i] = rand() % 1000000; // Fill with random numbers up to 1 million
    }
}

// Function to reverse the array (Worst Case for Bubble Sort)
void reverse_array(int arr[], int n) {
    int start = 0;
    int end = n - 1;
    while (start < end) {
        int temp = arr[start];
        arr[start] = arr[end];
        arr[end] = temp;
        start++;
        end--;
    }
}

// --- Algorithm Implementations ---

// 1. Linear Search (O(n))
// Returns the index of the element if found, or -1 if not found.
int linear_search(int arr[], int n, int target) {
    for (int i = 0; i < n; i++) {
        if (arr[i] == target) {
            return i;
        }
    }
    return -1;
}

// 2. Binary Search (O(log n))
// Requires the array to be sorted first.
int binary_search(int arr[], int low, int high, int target) {
    while (low <= high) {
        int mid = low + (high - low) / 2;
        if (arr[mid] == target)
            return mid;
        if (arr[mid] < target)
            low = mid + 1;
        else
            high = mid - 1;
    }
    return -1;
}

// 3. Bubble Sort (O(n^2))
void bubble_sort(int arr[], int n) {
    int i, j;
    for (i = 0; i < n - 1; i++) {
        for (j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                // Swap elements
                int temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
            }
        }
    }
}


// --- Main Test Harness ---

int main() {
    // Input sizes required by the task
    int n_values[] = {1000, 10000, 100000, 1000000};
    int num_tests = sizeof(n_values) / sizeof(n_values[0]);

    // Maximum size needed is 1,000,000
    int MAX_N = 1000000;
    int *arr_base = (int *)malloc(MAX_N * sizeof(int));
    if (arr_base == NULL) {
        fprintf(stderr, "Memory allocation failed.\n");
        return 1;
    }

    // Generate the base array once
    generate_random_array(arr_base, MAX_N);

    // Print headers for CSV/Excel
    printf("N,Linear_Search_Time_s,Binary_Search_Time_s,Bubble_Sort_Time_s\n");

    for (int i = 0; i < num_tests; i++) {
        int n = n_values[i];
        clock_t start, end;
        double cpu_time_used;

        // --- 1. Preparation and Copying ---
        // We only use the first 'n' elements from the base array
        int *arr = (int *)malloc(n * sizeof(int));
        for (int k = 0; k < n; k++) {
            arr[k] = arr_base[k];
        }

        // Output N value first
        printf("%d,", n);


        // -----------------------------------------------------------------
        // TEST 1: LINEAR SEARCH (O(n))
        // Worst Case: Target is the very last element.
        int target_linear = arr[n - 1]; 

        start = clock();
        linear_search(arr, n, target_linear);
        end = clock();
        cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
        printf("%.6f,", cpu_time_used);


        // -----------------------------------------------------------------
        // TEST 2: BINARY SEARCH (O(log n))
        // Binary search requires a sorted array. We use Bubble Sort (worst case) 
        // to sort a copy first, but we only measure the search time itself.

        // We use Bubble Sort to ensure the array is sorted.
        bubble_sort(arr, n); 
        
        // Target is chosen to be an element that exists (worst case for log n is finding it at the end)
        int target_binary = arr[n - 1]; 

        start = clock();
        binary_search(arr, 0, n - 1, target_binary);
        end = clock();
        cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
        printf("%.6f,", cpu_time_used); // Print time for Binary Search


        // -----------------------------------------------------------------
        // TEST 3: BUBBLE SORT (O(n^2))
        // Worst Case: Array is reverse sorted.

        // Reset the array copy (since Binary Search sorted it) and then reverse it
        for (int k = 0; k < n; k++) {
            arr[k] = arr_base[k];
        }
        reverse_array(arr, n); // Ensure worst-case O(n^2) scenario

        start = clock();
        bubble_sort(arr, n);
        end = clock();
        cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
        printf("%.6f\n", cpu_time_used); // Print time for Bubble Sort


        // Clean up memory for the current size array
        free(arr);
    }

    // Clean up base memory
    free(arr_base);

    return 0;
}